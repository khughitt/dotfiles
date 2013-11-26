"using strict";
/**
 * IPython Notebook extension settings
 * See: https://github.com/ipython-contrib/IPython-notebook-extensions
 */
$([IPython.events]).on('app_initialized.NotebookApp', function(){
    require(['custom/gist_it'])
    require(['custom/nbconvert_button'])
    require(['custom/split-combine'])
    require(['custom/navigation-hotkeys'])
    require(['custom/comment-uncomment'])
    require(['custom/shift-tab'])
    require(['custom/help_panel/help_panel'])
    require(['custom/noscroll'])
    require(['custom/clean_start'])
    require(['custom/toggle_all_line_number'])
    //require(['custom/nbviewer_theme/main'])

    //require(['custom/zenmode/main'],function(zenmode){
    //    zenmode.background('images/back12.jpg');
    //    console.log('Zenmode extension loaded correctly')
    //})
});
