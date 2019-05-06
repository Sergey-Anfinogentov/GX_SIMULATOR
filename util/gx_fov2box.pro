pro gx_fov2box,time, center_arcsec=center_arcsec, size_pix=size_pix, dx_km=dx_km, out_dir = out_dir, tmp_dir = tmp_dir,$
                        empty_box_only=empty_box_only,save_empty_box=save_save_empty_box,potential_only=potential_only,$
                        save_potential=save_potential,save_bounds=save_bounds,use_potential=use_potential,$
                        nlfff_only=nlfff_only, generic_only=generic_only, save_gxm=save_gxm,centre=centre,euv=euv,uv=uv,_extra=_extra
  setenv, 'WCS_RSUN=6.96d8'

  t0=systime(/seconds)
  message,'Downloading data',/cont
  if not keyword_set(tmp_dir) then tmp_dir = filepath('jsoc_cache',root = GETENV('IDL_TMPDIR'))
  if not file_test(tmp_dir) then file_mkdir, tmp_dir
  if not keyword_set(out_dir) then cd, current = out_dir
  out_dir=out_dir+path_sep()+anytim(strreplace(time,'.','-'),/ccsds,/date)
  if not file_test(out_dir) then file_mkdir, out_dir
  
  if not keyword_set(dx_km) then dx_km = 1000d
  if not keyword_Set(size_pix) then size_pix = [128,128,64]
  files = gx_box_download_hmi_data(time, tmp_dir)
  data=readfits(files.continuum,header)
  time=atime(sxpar(header,'date_obs'))
  if keyword_set(uv) or keyword_set(euv) then aia_files=gx_box_download_AIA_data(time, cache_dir = tmp_dir, uv=uv, euv=euv, _extra=_extra)
  if size(aia_files,/tname) eq 'STRUCT' then files = create_struct(files,aia_files)
  message,strcompress(string(systime(/seconds)-t0,format="('Data already found in the local repository or downloaded in ',g0,' seconds')")),/cont
  
  t0=systime(/seconds)
  message,'Creating the box structure',/cont
  ;for backward compatibility with deprecated "centre" input
  if n_elements(center_arcsec) ne 2 then if n_elements(centre) eq 2 then center_arcsec=centre
  if n_elements(center_arcsec) ne 2 then begin
    message,'Required center_arcsec input is missing or incorrect. Action aborted!',/cont
    return
  endif
  
  box = gx_box_create(files.field, files.inclination, files.azimuth,files.disambig, files.continuum, center_arcsec, size_pix, dx_km,_extra=_extra)
  if n_elements(files) gt 0   then begin
    if tag_exist(files,'magnetogram') then if file_test(files.magnetogram) then gx_box_add_refmap, box, files.magnetogram, id = 'Bz_reference'
    if tag_exist(files,'continuum') then if file_test(files.continuum) then gx_box_add_refmap, box, files.continuum, id = 'Ic_reference'
    if tag_exist(files,'AIA_94') then if file_test(files.AIA_94) then gx_box_add_refmap, box, files.aia_94,  id = 'AIA_94'
    if tag_exist(files,'AIA_131') then if file_test(files.AIA_131) then gx_box_add_refmap, box, files.aia_131, id = 'AIA_131'
    if tag_exist(files,'AIA_171') then if file_test(files.AIA_171) then gx_box_add_refmap, box, files.aia_171, id = 'AIA_171'
    if tag_exist(files,'AIA_193') then if file_test(files.AIA_193) then gx_box_add_refmap, box, files.aia_193, id = 'AIA_193'
    if tag_exist(files,'AIA_211') then if file_test(files.AIA_211) then gx_box_add_refmap, box, files.aia_211, id = 'AIA_211'
    if tag_exist(files,'AIA_304') then if file_test(files.AIA_304) then gx_box_add_refmap, box, files.aia_304, id = 'AIA_304'
    if tag_exist(files,'AIA_335') then if file_test(files.AIA_335) then gx_box_add_refmap, box, files.aia_335, id = 'AIA_335'
    if tag_exist(files,'AIA_1600') then if file_test(files.AIA_1600) then gx_box_add_refmap, box, files.aia_1600, id = 'AIA_1600'
    if tag_exist(files,'AIA_1700') then if file_test(files.AIA_1700) then gx_box_add_refmap, box, files.aia_1700, id = 'AIA_1700'
  endif   
  message,strcompress(string(systime(/seconds)-t0,format="('Box structure created in ',g0,' seconds')")),/cont  
  
  if keyword_set(empty_box_only) or keyword_set(save_empty_box) then begin
    save,box,file=out_dir+path_sep()+box.id+'.sav'
    message,'Empty box structure saved to '+out_dir+path_sep()+box.id+'.sav',/cont
  endif
  if keyword_set(empty_box_only) then return
  
  t0=systime(/seconds)
  message,'Performing initial potential extrapolation',/cont
  gx_box_make_potential_field, box,pbox
  message,strcompress(string(systime(/seconds)-t0,format="('Potential extrapolation performed in ',g0,' seconds')")),/cont
  
  if size(pbox,/tname) eq 'STRUCT' and ( keyword_set(save_potential) or keyword_set(potential_only) ) then begin
    save,pbox,file=out_dir+path_sep()+pbox.id+'.sav'
    message,'Potential box structure saved to '+out_dir+path_sep()+pbox.id+'.sav',/cont
  end
  
  if keyword_set(save_bounds) then begin
    save,box,file=out_dir+path_sep()+box.id+'.sav'
    message,'Bound Box structure saved to '+out_dir+path_sep()+box.id+'.sav',/cont
  endif
 
  if keyword_set(potential_only) then return
  
  if !VERSION.OS_FAMILY NE 'Windows' or keyword_set(use_potential) then begin
    if size(pbox,/tname) eq 'STRUCT' then box=temporary(pbox)
    goto,skip_nlfff
  endif
  
  t0=systime(/seconds)
  
  dirpath=file_dirname((ROUTINE_INFO('gx_box_make_potential_field',/source)).path,/mark)
  path=dirpath+'WWNLFFFReconstruction.dll'
  
  message,'Performing NLFFF extrapolation',/cont
  return_code = gx_box_make_nlfff_wwas_field(path, box)
  message,strcompress(string(systime(/seconds)-t0,format="('NLFFF extrapolation performed in ',g0,' seconds')")),/cont
  save,box,file=out_dir+path_sep()+box.id+'.sav'
  message,'NLFFF box structure saved to '+out_dir+path_sep()+box.id+'.sav',/cont
  
  if keyword_set(nlfff_only) then return
  
  skip_nlfff:
  t0=systime(/seconds)
  message,'Computing field lines for each voxel in the model..',/cont
  model=gx_importmodel(box)
  tr_height_km=1000
  tr_height=tr_height_km/(gx_rsun(unit='km'))
  model->computecoronalmodel,tr_height=tr_height,/compute,_extra=_extra
  message,strcompress(string(systime(/seconds)-t0,format="('Field line computation performed in ',g0,' seconds')")),/cont
  gx_model2box,model,box
  box.id=box.id+'.GEN'
  save,box,file=out_dir+path_sep()+box.id+'.sav'
  message,'Box structure saved to '+out_dir+path_sep()+box.id+'.sav',/cont
  
  if keyword_set(save_gxm) then begin
    model->SetProperty,id=box.id
    save,model,file=out_dir+path_sep()+box.id+'.gxm'
    message,'Model object saved to '+out_dir+path_sep()+box.id+'.gxm',/cont
  end
  obj_destroy,model
  if keyword_set(generic_only) then return 
  
  t0=systime(/seconds)
  message,'Generating chromo model..',/cont
  chromo_mask=decompose(box.base.bz,box.base.ic)
  box=combo_model(box,chromo_mask)
  message,strcompress(string(systime(/seconds)-t0,format="('Chromo model generated in ',g0,' seconds')")),/cont
  save,box,file=out_dir+path_sep()+box.id+'.sav'
  message,'Box structure saved to '+out_dir+path_sep()+box.id+'.sav',/cont
end