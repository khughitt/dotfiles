

  
  if &background == 'dark'
    
  let s:shade0 = "#44484f"
  let s:shade1 = "#576068"
  let s:shade2 = "#697981"
  let s:shade3 = "#7c919a"
  let s:shade4 = "#8faab4"
  let s:shade5 = "#a2c2cd"
  let s:shade6 = "#b4dbe6"
  let s:shade7 = "#c7f3ff"
  let s:accent0 = "#f59597"
  let s:accent1 = "#f2b494"
  let s:accent2 = "#f2db94"
  let s:accent3 = "#c8f29d"
  let s:accent4 = "#94f2dd"
  let s:accent5 = "#94cef2"
  let s:accent6 = "#db9cf7"
  let s:accent7 = "#f79ce0"
  
  endif
  

  
  if &background == 'light'
    
  let s:shade0 = "#dbf7ff"
  let s:shade1 = "#c5dde6"
  let s:shade2 = "#aec4cd"
  let s:shade3 = "#98aab4"
  let s:shade4 = "#81919a"
  let s:shade5 = "#6b7781"
  let s:shade6 = "#545e68"
  let s:shade7 = "#3e444f"
  let s:accent0 = "#e11418"
  let s:accent1 = "#e0530d"
  let s:accent2 = "#d2a623"
  let s:accent3 = "#61ab16"
  let s:accent4 = "#06b38b"
  let s:accent5 = "#34a4e7"
  let s:accent6 = "#a549cd"
  let s:accent7 = "#cc52ad"
  
  endif
  

  let s:p = {'normal': {}, 'inactive': {}, 'insert': {}, 'replace': {}, 'visual': {}, 'tabline': {}}
  let s:p.normal.left = [ [ s:shade1, s:accent5 ], [ s:shade7, s:shade2 ] ]
  let s:p.normal.right = [ [ s:shade1, s:shade4 ], [ s:shade5, s:shade2 ] ]
  let s:p.inactive.right = [ [ s:shade1, s:shade3 ], [ s:shade3, s:shade1 ] ]
  let s:p.inactive.left =  [ [ s:shade4, s:shade1 ], [ s:shade3, s:shade0 ] ]
  let s:p.insert.left = [ [ s:shade1, s:accent3 ], [ s:shade7, s:shade2 ] ]
  let s:p.replace.left = [ [ s:shade1, s:accent1 ], [ s:shade7, s:shade2 ] ]
  let s:p.visual.left = [ [ s:shade1, s:accent6 ], [ s:shade7, s:shade2 ] ]
  let s:p.normal.middle = [ [ s:shade5, s:shade1 ] ]
  let s:p.inactive.middle = [ [ s:shade4, s:shade1 ] ]
  let s:p.tabline.left = [ [ s:shade6, s:shade2 ] ]
  let s:p.tabline.tabsel = [ [ s:shade6, s:shade0 ] ]
  let s:p.tabline.middle = [ [ s:shade2, s:shade4 ] ]
  let s:p.tabline.right = copy(s:p.normal.right)
  let s:p.normal.error = [ [ s:accent0, s:shade0 ] ]
  let s:p.normal.warning = [ [ s:accent2, s:shade1 ] ]

  let g:lightline#colorscheme#ThemerVimLightline#palette = lightline#colorscheme#fill(s:p)

  