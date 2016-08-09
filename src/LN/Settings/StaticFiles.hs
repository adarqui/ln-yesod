{-# LANGUAGE TemplateHaskell #-}

-- https://hackage.haskell.org/package/yesod-static-1.5.0.3/docs/Yesod-EmbeddedStatic.html
-- Explains what functions get generated by staticFiles TH

module LN.Settings.StaticFiles (
  staticFiles,
  css_style_css,
  fonts_glyphicons_halflings_regular_eot,
  fonts_glyphicons_halflings_regular_svg,
  fonts_glyphicons_halflings_regular_ttf,
  fonts_glyphicons_halflings_regular_woff,
  img_loading_1_gif,
  img_loading_2_gif,
  img_loading_3_gif,
  img_loading_4_gif,
  img_404_png,
  img_oops_png,
  assets_bootstrap_css,
  assets_bootstrap_css_map,
  assets_favicon_ico,
  assets_react_js,
  assets_react_dom_js,
  assets_style_css,
  dist_all_js,
  dist_all_min_js,
  dist_all_min_js_gz,
  dist_index_html,
  dist_lib_js,
  dist_manifest_webapp,
  dist_out_js,
  dist_out_stats,
  dist_rts_js,
  dist_runmain_js
) where



import           LN.Settings  (appStaticDir, compileTimeAppSettings)
import           Yesod.Static (staticFiles)



-- This generates easy references to files in the static directory at compile time,
-- giving you compile-time verification that referenced files exist.
-- Warning: any files added to your static directory during run-time can't be
-- accessed this way. You'll have to use their FilePath or URL to access them.
--
-- For example, to refer to @static/js/script.js@ via an identifier, you'd use:
--
--     js_script_js
--
-- If the identifier is not available, you may use:
--
--     StaticFile ["js", "script.js"] []
staticFiles (appStaticDir compileTimeAppSettings)
