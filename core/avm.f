      real function avm_vdiff(ix,iy,iz,e,c1,ncut)
c
c c1 and ncut a user tunable control parameters. 
c Set c1 = 1.0 and reduce/increase as much possible/required.
c Typically ncut 1 or 2 works well. 
c
      include 'SIZE'
      include 'TOTAL'

      integer ix, iy, iz, e
      real c1, c2
      integer ncut
 
      logical ifcont
      parameter (ifcont=.false.)

      real visc(lx1,ly1,lz1,lelt)
      save visc

      parameter (lt=lx1*ly1*lz1*lelt)
      common /SCRMG/ r(lt),tx(lt),ty(lt),tz(lt) 

      parameter (lm=40)
      parameter (lm2=lm*lm)
      real hpf_filter(lm2)
      real hpf_op(lx1*lx1,ldimt1)
      save hpf_op

      integer ibuild(ldimt1)
      save    ibuild

      save    icalld
      data    icalld / 0 /

      real viscc(8,lelt)

      if (ix*iy*iz*e .ne. 1) then ! use cache
         avm_vdiff = visc(ix,iy,iz,e)
         return
      endif

      if (icalld.eq.0) then
         do i = 1,ldimt1
            ibuild(i) = 0
         enddo
         icalld = 1
      endif

      nxyz = lx1*ly1*lz1
      n    = nxyz*nelv
      c2   = 0.5
      iffilter(ifield) = .false.

      ! compute residual
      if (ifield.eq.1) then
         if (nid.eq.0) write(6,*) 'avm not supported for ifield=1 !'
         call exitt
      else
         if (ibuild(ifield).eq.0) then
           call hpf_trns_fcn(hpf_filter,ncut)
           call build_hpf_mat(hpf_op(1,ifield),hpf_filter,.false.)
           ibuild(ifield) = ibuild(ifield) + 1
         endif
         call build_hpf_fld(r,t(1,1,1,1,ifield-1),hpf_op(1,ifield),
     $                      lx1,lz1)

         psave = param(99)
         param(99) = 0
         call copy(tx,r,n)
         call convop(r,tx)
         param(99) = psave

         ! normalize
         uavg = gl2norm(t(1,1,1,1,ifield-1),n)
         call cfill(tx,uavg,n)
         call sub2(tx,t(1,1,1,1,ifield-1),n)
         uinf = 1.
         if(uavg.gt.0) uinf = glamax(tx, n)
      endif

      ! evaluate arificial viscosity
      uinf = 1./uinf
      do i = 1,n
        h0 = deltaf(i,1,1,1)
        vmax  = sqrt(vx(i,1,1,1)**2 + vy(i,1,1,1)**2 + vz(i,1,1,1)**2)
        vismax = c2 * h0 * vmax
        visc(i,1,1,1) = min(vismax, c1 * h0**2 * abs(r(i)) * uinf)
      enddo

      ! make it piecewise constant
      do ie = 1,nelv
         vmax = vlmax(visc(1,1,1,ie),nxyz)
         call cfill(visc(1,1,1,ie),vmax,nxyz)
      enddo

      ! make it P1 continuous
      if (ifcont) then
         call dsop (visc,'max',lx1,ly1,lz1)
         do ie = 1,nelv 
           viscc(1,ie) = visc(1  ,1  ,1  ,ie)
           viscc(2,ie) = visc(lx1,1  ,1  ,ie)
           viscc(3,ie) = visc(1  ,ly1,1  ,ie)
           viscc(4,ie) = visc(lx1,ly1,1  ,ie)

           viscc(5,ie) = visc(1  ,1  ,lz1,ie)
           viscc(6,ie) = visc(lx1,1  ,lz1,ie)
           viscc(7,ie) = visc(1  ,ly1,lz1,ie)
           viscc(8,ie) = visc(lx1,ly1,lz1,ie)
         enddo 
         call map_c_to_f_h1_bilin(visc,viscc)
      endif

      if (mod(istep,10).eq.0) then
        vismx = glamax(visc,n)
        vismn = glamin(visc,n)
        visav = glsc2(visc,bm1,n)/volvm1
        if (nio.eq.0) write(6,10) time,vismx,vismn,visav,ifield
 10     format(1p4e12.4,' AVM',i6)
      endif

      avm_vdiff = visc(ix,iy,iz,e)

      return
      end
c---------------------------------------------------------------
      real function deltaf(ix,iy,iz,iel)
c
      include 'SIZE'
      include 'TOTAL'

      real dxc(8,lelt)

      real dx(lx1,ly1,lz1,lelt)
      save dx 

      data icalld /0/
      save icalld

      nxyz = nx1*ny1*nz1
      n    = nxyz*nelv

      if (icalld.eq.0) then
         dinv = 1./ldim
         do ie = 1,nelv
            volavg = 0
            do i  = 1,nxyz
               volavg = volavg + bm1(i,1,1,ie)
            enddo
            call cfill(dx(1,1,1,ie),(volavg**dinv)/lx1,nxyz) 
         enddo
   
         ! make it P1 continuous
         call dsop (dx,'max',lx1,ly1,lz1)
         do ie = 1,nelv
           dxc(1,ie) = dx(1  ,1  ,1  ,ie)
           dxc(2,ie) = dx(lx1,1  ,1  ,ie)
           dxc(3,ie) = dx(1  ,ly1,1  ,ie)
           dxc(4,ie) = dx(lx1,ly1,1  ,ie)
   
           dxc(5,ie) = dx(1  ,1  ,lz1,ie)
           dxc(6,ie) = dx(lx1,1  ,lz1,ie)
           dxc(7,ie) = dx(1  ,ly1,lz1,ie)
           dxc(8,ie) = dx(lx1,ly1,lz1,ie)
         enddo
         call map_c_to_f_h1_bilin(dx,dxc)
         icalld = 1
      endif

      deltaf = dx(ix,iy,iz,iel)

      end 
