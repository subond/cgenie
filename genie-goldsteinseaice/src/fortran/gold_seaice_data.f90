MODULE gold_seaice_data

  USE gold_seaice_lib
  USE gold_seaice_netcdf
  IMPLICIT NONE

CONTAINS
  SUBROUTINE inm_seaice(unit)
    IMPLICIT NONE
    INTEGER, INTENT(IN) :: unit
    INTEGER :: i, j, l, icell
    REAL :: tmp_val(4)

    READ (unit,*) (((varice(l,i,j), l = 1, 2), i = 1, imax), j = 1, jmax)
    READ (unit,*) ((tice(i,j), i = 1, imax), j = 1, jmax)
    READ (unit,*) ((albice(i,j), i = 1, imax), j = 1, jmax)

    IF (debug_init) &
         & WRITE (*,320) 'Avg height', 'Avg area', 'Avg T', 'Avg albedo'

    tmp_val = 0
    icell = 0

    ! Sum layer state variables and flow field
    DO j = 1, jmax
       DO i = 1, imax
          IF (k1(i,j) <= kmax .AND. varice(2,i,j) > 0.0) THEN
             icell = icell + 1
             tmp_val(1:2) = tmp_val(1:2) + varice(:,i,j)
             tmp_val(3) = tmp_val(3) + tice(i,j)
             tmp_val(4) = tmp_val(4) + albice(i,j)
          END IF
       END DO
    END DO

    ! Print average values out
    IF (icell > 0) THEN
       IF (debug_init) WRITE (*,310) tmp_val(1) / icell, tmp_val(2) / icell, &
            & tmp_val(3) / icell, tmp_val(4) / icell
    ELSE
       IF (debug_init) WRITE (*,310) 0.0, 0.0, 0.0, 0.0
    END IF

310 FORMAT(4f13.9)
320 FORMAT(4a13)
  END SUBROUTINE inm_seaice


  ! Read in netCDF restart files for GOLDSTEIN sea-ice
  SUBROUTINE inm_netcdf_sic
    IMPLICIT NONE
    INCLUDE 'netcdf.inc'

    REAL, DIMENSION(maxi,maxj) :: hght_read, frac_read, temp_read, albd_read

    INTEGER :: iday, ifail, ncid
    LOGICAL :: lexist
    CHARACTER(LEN=200) :: fnamein
    REAL :: timestep
    INTEGER :: i, j, icell
    REAL :: tmp_val(4)

    timestep = 24.0 * 60.0 * 60.0 * yearlen / REAL(nyear)
    fnamein = TRIM(filenetin)
    ifail = 0
    INQUIRE(FILE=TRIM(fnamein), EXIST=lexist)
    IF (.NOT. lexist) THEN
       PRINT *, ' Missing file ', TRIM(fnamein)
       PRINT *, ' Correct error and try again '
       STOP 1
    END IF

    PRINT *, ' goldstein sea-ice: Opening restart file for read: ', &
         & TRIM(filenetin)

    CALL open_file_nc(TRIM(fnamein), ncid)
    CALL get1di_data_nc(ncid,'ioffset', 1, ioffset_rest, ifail)
    CALL get1di_data_nc(ncid,'iyear',   1, iyear_rest,   ifail)
    CALL get1di_data_nc(ncid,'imonth',  1, imonth_rest,  ifail)
    CALL get1di_data_nc(ncid,'iday',    1, iday,         ifail)
    CALL get2d_data_nc(ncid,'sic_height', maxi, maxj, hght_read, ifail)
    CALL get2d_data_nc(ncid,'sic_cover',  maxi, maxj, frac_read, ifail)
    CALL get2d_data_nc(ncid,'sic_temp',   maxi, maxj, temp_read, ifail)
    CALL get2d_data_nc(ncid,'sic_albedo', maxi, maxj, albd_read, ifail)
    CALL close_file_nc(TRIM(filenetin),ncid)

    day_rest = iday
    ioffset_rest = MOD(ioffset_rest, NINT(yearlen))

    day_rest = day_rest + timestep / (24 * 60 * 60.0)
    ! This bit so that we don't get too far out in our count....
    ! Anchor to a day if we start drifting.
    ! Means timestep can never be less than 1/1000 of a day!!!!
    IF (ABS(iday - day_rest) <= 1.0E-3) day_rest = iday
    IF (day_rest >= 31) THEN
       day_rest = day_rest - 30
       imonth_rest = imonth_rest + 1
       IF (imonth_rest == 13) THEN
          imonth_rest = 1
          iyear_rest = iyear_rest + 1
       END IF
    END IF
    iday = NINT(day_rest)
    IF (debug_init) PRINT *, 'day in goldstein sea-ice restart is now', day_rest
    IF (debug_init) PRINT *, 'iday in goldstein sea-ice restart is now', iday

    varice(1,1:maxi,1:maxj) = hght_read(:,:)
    varice(2,1:maxi,1:maxj) = frac_read(:,:)
    tice(1:maxi,1:maxj) = temp_read(:,:)
    albice(1:maxi,1:maxj) = albd_read(:,:)

    ! Write out averages for restart checks
    IF (debug_init) &
         & WRITE (*,320) 'Avg height','Avg area', 'Avg T', 'Avg albedo'
    tmp_val = 0
    icell = 0
    DO j = 1, jmax
       DO i = 1, imax
          IF (k1(i,j) <= kmax .AND. varice(2,i,j) > 0.0) THEN
             icell = icell + 1
             tmp_val(1:2) = tmp_val(1:2) + varice(:,i,j)
             tmp_val(3) = tmp_val(3) + tice(i,j)
             tmp_val(4) = tmp_val(4) + albice(i,j)
          END IF
       END DO
    END DO
    IF (icell > 0) THEN
       IF (debug_init) WRITE (*,310) tmp_val(1) / icell, tmp_val(2) / icell, &
            & tmp_val(3) / icell, tmp_val(4) / icell
    ELSE
       IF (debug_init) WRITE (*,310) 0.0, 0.0, 0.0, 0.0
    END IF

310 FORMAT(4f13.9)
320 FORMAT(4a13)
  END SUBROUTINE inm_netcdf_sic


  SUBROUTINE outm_seaice(unit)
    IMPLICIT NONE
    INTEGER, INTENT(IN) :: unit
    INTEGER :: i, j, icell
    REAL :: tmp_val(4)

    WRITE (unit,FMT='(e24.15)') varice
    WRITE (unit,FMT='(e24.15)') tice
    WRITE (unit,FMT='(e24.15)') albice

    IF (debug_loop) &
         & WRITE (*,320) 'Avg height','Avg area', 'Avg T', 'Avg albedo'
    tmp_val = 0
    icell = 0
    DO j = 1, jmax
       DO i = 1, imax
          IF (k1(i,j) <= kmax .AND. varice(2,i,j) > 0.0) THEN
             icell = icell + 1
             tmp_val(1:2) = tmp_val(1:2) + varice(:,i,j)
             tmp_val(3) = tmp_val(3) + tice(i,j)
             tmp_val(4) = tmp_val(4) + albice(i,j)
          END IF
       END DO
    END DO
    IF (icell > 0) THEN
       IF (debug_loop) WRITE (*,310) tmp_val(1) / icell, tmp_val(2) / icell, &
            & tmp_val(3) / icell, tmp_val(4) / icell
    ELSE
       IF (debug_loop) WRITE (*,310) 0.0, 0.0, 0.0, 0.0
    END IF

310 FORMAT(4f13.9)
320 FORMAT(4a13)
  END SUBROUTINE outm_seaice


  SUBROUTINE outm_netcdf_sic(istep)
    IMPLICIT NONE
    INCLUDE 'netcdf.inc'

    INTEGER istep

    REAL, DIMENSION(maxi,maxj) :: hght_write, frac_write, temp_write, albd_write
    REAL :: lons1(maxi), lats1(maxj)
    INTEGER :: landmask(maxi,maxj)
    INTEGER :: i, j, nhghtid, nfracid, ntempid, nalbdid
    INTEGER :: nlon1id, nlongit1id, nlat1id, nlatit1id, nrecsid, ioffsetid
    INTEGER :: dim1pass(2)
    CHARACTER(LEN=200) :: fname

    INTEGER :: iday, iyearid, imonthid, idayid
    CHARACTER(LEN=10) :: yearstring
    CHARACTER(LEN=2) :: monthstring, daystring
    CHARACTER(LEN=7) :: datestring

    INTEGER :: status, ncid
    REAL :: timestep

    INTEGER :: icell
    REAL :: tmp_val(4)

    timestep = yearlen / REAL(nyear)

    ! output file format is yyyy_mm_dd
    ! 30 day months are assumed
    IF (MOD(yearlen,30.0) /= 0) THEN
       PRINT *, 'ERROR: Goldstein NetCDF restarts (outm_netdf):'
       PRINT *, '   mod(yearlen,30.0) must be zero'
       STOP
    END IF

    iday = NINT(day_rest)
    IF (MOD(istep,iwstp) == 0) THEN
       ! WRITE A RESTART.....
       lons1 = nclon1
       lats1 = nclat1
       landmask = 0
       ! Next line contains an explicit reference to the values
       ! used in the topography grid (i.e. < 90) - not ideal,
       ! but the routine doesn't know about maxk
       WHERE (k1(1:maxi,1:maxj) < 90) landmask = 1

       hght_write = REAL(varice(1,:,:) * landmask)
       frac_write = REAL(varice(2,:,:) * landmask)
       temp_write = REAL(tice)
       albd_write = REAL(albice)

       WRITE (datestring,'(i7.7)') istep
       WRITE (yearstring,'(i10)') iyear_rest
       WRITE (monthstring,'(i2.2)') imonth_rest
       WRITE (daystring,'(i2.2)') iday

       fname = TRIM(dirnetout) // '/goldsic_restart_' // &
            & TRIM(ADJUSTL(yearstring)) // '_' // monthstring // '_' // &
            & daystring // '.nc'
       PRINT *, ' Opening netcdf restart file for write: ', TRIM(fname)
       status = NF_CREATE(TRIM(fname), NF_CLOBBER, ncid)
       CALL check_err(status)
       status = NF_DEF_DIM(ncid, 'nrecs', 1, nrecsid)
       CALL check_err(status)
       status = NF_DEF_DIM(ncid, 'longitude', maxi, nlon1id)
       CALL check_err(status)
       status = NF_DEF_DIM(ncid, 'latitude', maxj, nlat1id)
       CALL check_err(status)

       status = NF_DEF_VAR(ncid, 'longitude', NF_REAL, 1, nlon1id, nlongit1id)
       CALL check_err(status)
       status = NF_DEF_VAR(ncid, 'latitude', NF_REAL, 1, nlat1id, nlatit1id)
       CALL check_err(status)
       dim1pass(1) = nlon1id
       dim1pass(2) = nlat1id
       status = NF_DEF_VAR(ncid, 'ioffset', NF_INT, 1, nrecsid, ioffsetid)
       CALL check_err(status)
       status = NF_DEF_VAR(ncid, 'iyear', NF_INT, 1, nrecsid, iyearid)
       CALL check_err(status)
       status = NF_DEF_VAR(ncid, 'imonth', NF_INT, 1, nrecsid, imonthid)
       CALL check_err(status)
       status = NF_DEF_VAR(ncid, 'iday', NF_INT, 1, nrecsid, idayid)
       CALL check_err(status)

       status = NF_DEF_VAR(ncid, 'sic_height', NF_DOUBLE, 2, dim1pass, nhghtid)
       CALL check_err(status)
       status = NF_DEF_VAR(ncid, 'sic_cover', NF_DOUBLE, 2, dim1pass, nfracid)
       CALL check_err(status)
       status = NF_DEF_VAR(ncid, 'sic_temp', NF_DOUBLE, 2, dim1pass, ntempid)
       CALL check_err(status)
       status = NF_DEF_VAR(ncid, 'sic_albedo', NF_DOUBLE, 2, dim1pass, nalbdid)
       CALL check_err(status)
       CALL check_err(NF_ENDDEF(ncid))

       CALL check_err(NF_PUT_VAR_INT(ncid, iyearid, iyear_rest))
       CALL check_err(NF_PUT_VAR_INT(ncid, imonthid, imonth_rest))
       CALL check_err(NF_PUT_VAR_INT(ncid, idayid, iday))
       CALL check_err(NF_PUT_VAR_INT(ncid, ioffsetid, ioffset_rest))

       CALL check_err(NF_PUT_VAR_DOUBLE(ncid, nlongit1id, lons1))
       CALL check_err(NF_PUT_VAR_DOUBLE(ncid, nlatit1id, lats1))
       CALL check_err(NF_PUT_VAR_DOUBLE(ncid, nhghtid, hght_write))
       CALL check_err(NF_PUT_VAR_DOUBLE(ncid, nfracid, frac_write))
       CALL check_err(NF_PUT_VAR_DOUBLE(ncid, ntempid, temp_write))
       CALL check_err(NF_PUT_VAR_DOUBLE(ncid, nalbdid, albd_write))

       status = NF_CLOSE(ncid)

       WRITE (*,320) 'Avg height','Avg area', 'Avg T', 'Avg albedo'
       tmp_val = 0
       icell = 0
       DO j = 1, jmax
          DO i = 1, imax
             IF (k1(i,j) <= kmax .AND. varice(2,i,j) > 0.0) THEN
                icell = icell + 1
                tmp_val(1:2) = tmp_val(1:2) + varice(:,i,j)
                tmp_val(3) = tmp_val(3) + tice(i,j)
                tmp_val(4) = tmp_val(4) + albice(i,j)
             END IF
          END DO
       END DO
       IF (icell > 0) THEN
          WRITE (*,310) tmp_val(1) / icell, tmp_val(2) / icell, &
               & tmp_val(3) / icell, tmp_val(4) / icell
       ELSE
          WRITE (*,310) 0.0, 0.0, 0.0, 0.0
       END IF

310    FORMAT(4f13.9)
320    FORMAT(4a13)
    END IF

    day_rest = day_rest + timestep
    ! This bit so that we don't get too far out in our count....
    ! Anchor to a day if we start drifting.
    ! Means timestep can never be less than 1/1000 of a day!!!!
    IF (ABS(iday - day_rest) <= 1.0E-3) THEN
       PRINT *, 'CORRECTING TIME-LAG! in outm_netcdf in genie-goldstein', &
            & iday, day_rest
       day_rest = iday
    END IF
    IF (day_rest >= 31) THEN
       day_rest = day_rest - 30
       imonth_rest = imonth_rest + 1
       IF (imonth_rest == 13) THEN
          imonth_rest = 1
          iyear_rest = iyear_rest + 1
       END IF
    END IF
    iday = NINT(day_rest)
  END SUBROUTINE outm_netcdf_sic


  SUBROUTINE diagsic(istep)
    IMPLICIT NONE
    INTEGER, INTENT(IN) :: istep

    REAL, DIMENSION(2) :: hamax, hamin, haaav
    REAL :: ticemax, ticemin, ticeaav, albicemax, albicemin, albiceaav, area
    INTEGER :: i, j, l, icepts

    DO l = 1, 2
       hamax(l) = MAXVAL(varice(l,:,:))
       hamin(l) = MINVAL(varice(l,:,:))
    END DO
    ticemax = MAXVAL(tice)
    ticemin = MINVAL(tice)
    albicemax = MAXVAL(albice)
    albicemin = MINVAL(albice)
    haaav = 0.0
    ticeaav = 0.0
    albiceaav = 0.0
    icepts = 0
    area = 0.0

    DO j = 1, jmax
       DO i = 1, imax
          IF (varice(2,i,j) > 0.0) THEN
             haaav(1) = haaav(1) + varice(1,i,j) * ds(j)
             haaav(2) = haaav(2) + varice(2,i,j) * ds(j)
             ticeaav = ticeaav + tice(i,j)
             albiceaav = albiceaav + albice(i,j)
             icepts = icepts + 1
             area = area + ds(j)
          END IF
       END DO
    END DO
    IF (icepts > 0) THEN
       haaav = haaav / area
       ticeaav = ticeaav / area
       albiceaav = albiceaav / area
    END IF
    PRINT *, 'Sea-ice properties at time ', istep
    PRINT *, 'Ice height : max = ', hamax(1), '; min = ', hamin(1), &
         & '; avg = ', haaav(1)
    PRINT *, 'Ice cover  : max = ', hamax(2), '; min = ', hamin(2), &
         & '; avg = ', haaav(2)
    PRINT *, 'Ice temp.  : max = ', ticemax, '; min = ', ticemin, &
         & '; avg = ', ticeaav
    PRINT *, 'Ice albd.  : max = ', albicemax, '; min = ', albicemin, &
         & '; avg = ', albiceaav
  END SUBROUTINE diagsic


  ! Extra diagnostic routine for c-goldstein v2 with seasonal cycle
  ! calculate average over nyear timesteps.
  SUBROUTINE diagosc_sic(istep, iout, ext, fx_delta, fw_delta)
    USE genie_util, ONLY: check_unit, check_iostat
    IMPLICIT NONE
    INTEGER, INTENT(IN) :: istep, iout
    CHARACTER(LEN=3), INTENT(IN) :: ext
    REAL, DIMENSION(maxi,maxj), INTENT(IN) :: fx_delta, fw_delta

    INTEGER :: ios, l
    REAL :: rnyear, work((maxi+1) * (maxj+1))

    rnyear = 1.0 / nyear
    DO l = 1, 2
       haavg(l,:,:) = SUM(varice(l,:,:) * rnyear)
       dthaavg(l,:,:) = SUM(dtha(l,:,:) * rnyear)
    END DO
    ticeavg = SUM(tice * rnyear)
    albiceavg = SUM(albice * rnyear)
    fxdelavg = SUM(fx_delta * rnyear)
    fwdelavg = SUM(fw_delta * rnyear)

    IF (iout == 1) THEN
       PRINT *, 'Sea-ice : writing averaged data at istep ', istep

       ! write averaged data (a near-copy of outm.f) not a restart
       ! as such, therefore can write less accurate, more economical output
       CALL check_unit(2, __LINE__, __FILE__)
       OPEN(2, FILE=outdir_name(1:lenout) // lout // '.osc.' // ext, IOSTAT=ios)
       CALL check_iostat(ios, __LINE__, __FILE__)
       WRITE (2,10,IOSTAT=ios) haavg
       CALL check_iostat(ios, __LINE__, __FILE__)
       WRITE (2,10,IOSTAT=ios) ticeavg
       CALL check_iostat(ios, __LINE__, __FILE__)
       WRITE (2,10,IOSTAT=ios) albiceavg
       CALL check_iostat(ios, __LINE__, __FILE__)
       WRITE (2,10,IOSTAT=ios) dthaavg(1,:,:)
       CALL check_iostat(ios, __LINE__, __FILE__)
       WRITE (2,10,IOSTAT=ios) dthaavg(2,:,:)
       CALL check_iostat(ios, __LINE__, __FILE__)
       WRITE (2,10,IOSTAT=ios) fxdelavg
       CALL check_iostat(ios, __LINE__, __FILE__)
       WRITE (2,10,IOSTAT=ios) fwdelavg
       CALL check_iostat(ios, __LINE__, __FILE__)
       CLOSE(2,IOSTAT=ios)
       CALL check_iostat(ios, __LINE__, __FILE__)

       PRINT *, 'Writing sea-ice mean annual netCDF file at time', istep
       CALL ini_netcdf_sic(istep, 2)
       CALL write_netcdf_sic(k1, haavg, ticeavg, albiceavg, dthaavg, &
            & fxdelavg, fwdelavg, work, maxi, maxj, 2)
       CALL end_netcdf_sic(2)
       PRINT *

       ! increment average counter
       iav = iav + 1

       ! perform diagnostics on averaged data, either by rewriting other diag
       ! routines to accept data as argument, or by simply copying code,
       ! otherwise diagnose by integrating one (short) step from .avg file.
       PRINT *, 'Sea-ice : resetting averaged data arrays at step', istep
       haavg = 0.0
       ticeavg = 0.0
       albiceavg = 0.0
       dthaavg = 0.0
       dthaavg = 0.0
       fxdelavg = 0.0
       fwdelavg = 0.0
       PRINT *
    END IF

10  FORMAT(e14.7)
  END SUBROUTINE diagosc_sic

END MODULE gold_seaice_data
