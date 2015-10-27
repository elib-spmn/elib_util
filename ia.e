<'

struct import_analysis_s {
    !dir    : string;
    !is_imported_in_dir : bool;
    !is_added_to_makefile : bool;
    !has_direct_imports : bool;
    module : rf_module;
};

extend rf_module {
    !refs_to : list of entity_reference;
    !refs_from : list of entity_reference;
    !modules_referenced : list of rf_module;
    !modules_imported : list of rf_module;
};

extend entity_reference {
    !mod_from : rf_module;
    !mod_to : rf_module;
};

struct import_analyzer {
    !ias : list of import_analysis_s;
    !tops : list of import_analysis_s;
    !user_modules : list of rf_module;
    !included_tops : list of string;
    top_module: string;
   
    analyze_imports() is {

        user_modules = rf_manager.get_user_modules();
        var F := files.open("modules.txt", "w", "Modules file");
        for each (um) in user_modules {
            files.write(F, um.get_full_file_name());
            ias.add(new import_analysis_s with {
                    .module = um;
                    .dir = um.get_full_file_name();
                    .has_direct_imports = (um.get_direct_imports().size() > 0);
                    });
            if (ias.top().dir ~ "/^(.*)\/[^\/]*$/") {
                ias.top().dir = $1;
            };
            messagef(LOW, "module %s has dir %s\n", um.get_full_file_name(), ias.top().dir);
        };
        files.close(F);

        for each (dir) in ias.sort(.dir).unique(.dir).dir {
            for each (od) in ias.all(.dir == dir) {
                for each (id) in ias.all(.dir == dir && !.is_imported_in_dir) {
                    if id.module.get_all_imports().has(it == od.module) {
                        od.is_imported_in_dir = TRUE;
                        break;
                    };
                };  
            };
        };
        for each (mod) in ias.all(not .is_imported_in_dir and .has_direct_imports) {
            outf("Module %s is top in directory : %s\n", mod.module.get_name(), mod.dir);
            --if (included_tops.has(it == mod.module.get_name())) {
                tops.add(mod);
            --};
        };

        out("Generating graph....");
        F = files.open("graph.txt", "w", "Module visualization file");
        files.write(F, append("graph {"));
        files.write(F, append("    graph [ratio=\".75\"];"));
        for each (om) in tops {
            files.write(F, append("   ", om.module.get_name(), "_", om.module.get_index(), ";"));
            for each (im) in tops {
                if (om.module.get_all_imports().has(it == im.module)) {
                    files.write(F, append("   ", om.module.get_name(), "_", om.module.get_index(), " -- ", im.module.get_name(), "_", im.module.get_index(), ";"));
                };
            };
        };
        files.write(F, append("}"));
        files.close(F);
        out("Done!");
    };

    ia_visualize(top:string) is empty;
};

extend sys {
    import_analyzer : import_analyzer;

    post_generate() is also {
        import_analyzer.analyze_imports();
    };
};

'>
