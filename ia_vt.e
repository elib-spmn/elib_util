<'
extend vt_page_kind: [TOPS_CHOOSER_PAGE];
extend vt_window_kind: [IA];
extend IA vt_window {
    configure() is also {
        // geometry
        set_location(250, 100);
        set_size(600, 500);
        // menus
        --add_menu("Packets");
        --add_menu_item("Packets", "Show Packets", "Show all packets", "%appl.show_packets()", NULL, "Show Packets");
        --add_menu_separator("Packets");
        --add_toolbar_separator();
        --add_menu_item("Packets", "Show Packet Definition", "Show e code of packet definition", "source packet", NULL, "Packet Def");
        // symbols
        set_symbol_value("appl", "sys.import_analyzer");
        // title
        set_title_prefix("Import Analyzer");
    };
};

extend import_analyzer {
    // create the HTML for the list of packets page
    create_tops_list_html_body(): list of string is {
        // print the header of page
        result.add(appendf("List of potential tops contains %s tops:", tops.size()));
        result.add(vt.btn_command("sys.import_analyzer.analyze_selected_tops()", "Analyze Selected Tops"));
        if (tops.is_empty()) {
            return result;
        };
        result.add("<table>");
        // go over all packets and add a line for each one
        for each (top) in tops {
            var file_name := top.module.get_full_file_name();
            var module_name := top.module.get_name();
            var box := vt.inp_checkbox(module_name, FALSE);
            result.add(appendf("<tr><td>%s</td><td>%s</td><td>%s</td><tr>", box, module_name, file_name));
        };
        result.add("</table>");
    };

    !chooser_page : TOPS_CHOOSER_PAGE vt_page;

    // open the Show Packets page
    show_tops() is {
        chooser_page = new TOPS_CHOOSER_PAGE vt_page with {
            .set_window_kind(IA);
            .set_html_body(create_tops_list_html_body());
            .set_title(append("List Of Tops"));
        };
        chooser_page.show();
    };

    analyze_selected_tops() is {
        var selected_tops : list of string;
        for each (top) in tops {
            var modname := top.module.get_name();
            if (chooser_page.get_widget_value(modname) == "TRUE") {
                messagef(LOW, "Top file %s selected\n", top.module.get_full_file_name());
                selected_tops.add(modname);
            };
        };
        lint_manager.report_common_elibs(top_module, selected_tops);
    };

   ia_visualize(top:string) is {
      top_module = top;
      show_tops();
    };
};

'>
