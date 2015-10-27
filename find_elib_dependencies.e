<'

extend rf_module {
    // Collect modules imported and/or used by this module directly.
    // Add them to the 'res' list, unless they are already there.
    // If include_imports=FALSE, collect only used modules, but not imported.
    collect_used_modules(include_imports: bool, res: list (key: it) of rf_module) is {
        if res.key_exists(me) then {
            // Avoid infinite recursion. This module was already handled before.
            return;
        };
        res.add(me);
        if include_imports then {
            // Add modules imported by this module directly (it has 'import' statement for them).
            for each (m) in get_direct_imports() do {
                m.collect_used_modules(include_imports, res);
            };
        };
        for each (ref) in lint_manager.all_refs do {
            if ref.get_source_module() == me then {
                // If some entity is referenced by this module, and it was declared in another module,
                // then this module uses the other module (it cannot be compiled without that module).
                // For example, this module has a method call, and the method is declared in the other module.
                var def_module: rf_module = ref.get_entity().get_declaration_module();
                if def_module.is_user_module() then {
                    def_module.collect_used_modules(include_imports, res);
                };
            };
        };
    };
    
    // Find all modules on which this module depends recursively.
    get_all_used_modules(include_imports: bool): list of rf_module is {
        // We use lint_manager.tmp_list field rather than a local list variable,
        // simply to avoid allocating a new list every time this method is called,
        // which could cause a performance overhead.
        // Logically it could have been a local variable.
        collect_used_modules(include_imports, lint_manager.tmp_list);
        if include_imports then {
            result = lint_manager.tmp_list.as_a(list of rf_module);
        } else {
            result = lint_manager.tmp_list.all(it != me);
        };
        lint_manager.tmp_list.clear();
    };
};

// A struct to represent dependencies between elibs and modules.
// For example, assume that both uvc1 and uvc2 use uvm_e and vr_ad.
// There will be an instance of this struct, with depending_elibs={uvc1_top;uvc2_top}
// and modules={uvm_e_top;vr_ad_top}.
struct elib_dependency_info like base_struct {
    // A list of elibs that share the same list of modules on which they depend.
    // Each elib is represented here by its top module.
    depending_elibs: list of rf_module;
    
    // The list of modules on which the elibs depend.
    // It means that in order to compile all of the above elibs,
    // there must be a common elib (or elibs) that contain(s) these modules.
    modules: list of rf_module;
};

extend lint_manager {
    tmp_list: list (key: it) of rf_module;
    
    // Hold all entity references in the code.
    all_refs: list of entity_reference;
    
    find_common_elibs_by_names(top_module_name: string, elib_top_names: list of string): list of elib_dependency_info is {
        var top_module: rf_module = rf_manager.get_module_by_name(top_module_name);
        var elib_top_modules: list of rf_module = elib_top_names.apply(rf_manager.get_module_by_name(it));
        var wrong_names: list of string;
        if top_module == NULL then {
            wrong_names.add(top_module_name);
        };
        for each in elib_top_modules do {
            if it == NULL then {
                wrong_names.add(elib_top_names[index]);
            };
        };
        if not wrong_names.is_empty() then {
            error("Non-existing module name(s) given: ", str_join(wrong_names, ", "));
        };
        return find_common_elibs(top_module, elib_top_modules);
    };

    // This method gets a top module and a list of desired elibs (the top module for each elib),
    // and returns an elib dependencies list.
    // So, as a result of calling this method, we get information regarding which elibs depend on each modules commonly.
    // Each such module will need to also be compiled into a separate elib,
    // and the depending elibs will need to be compiled on top of those.
    find_common_elibs(top_module: rf_module, elib_tops: list of rf_module): list of elib_dependency_info is {

        if top_module == NULL or elib_tops.has(it == NULL) then {
            error("NULL is passed as one of the modules");
        };
        
        // If only one elib_top is given, no dependencies can be found. See explanation below.
        if elib_tops.size() <= 1 then {
            error("At least two e-library top modules should be given");
        };
        
        for each (m) in elib_tops do {
            if elib_tops.count(it == m) > 1 then {
                error("Module '", m.get_name(), "' is given twice in the list");
            };
        };
        
        // For each elib, it will hold the list of all modules that need to be compiled separately,
        // and the elib needs to be compiled on top of those.
        // It includes both imported and used modules.
        // A used module is a module that declare any entities referenced (used) by the given elib,
        // even if it doesn't import it explicitly.
        // For example, it might be that a top file can import both uvc_top and vr_ad_top,
        // and uvc may use entities declared in vr_ad but not import vr_ad_top directly.
        var elib_modules: list of list of rf_module;
    
        // Detect all entity references in the code.
        // For this method to function, we need to have 'config misc -lint_mode' be set before loading or compiling the code,
        // otherwise this method will return an empty result.
        all_refs = get_all_entity_references();
        
        for each (elib_top) in elib_tops do {
            // For each elib, find all the modules on which it depends.
            elib_modules.add(elib_top.get_all_used_modules(TRUE));
        };

        // Collect all modules on which the top module depends.
        var all_modules: list of rf_module = top_module.get_all_used_modules(TRUE);
        var all_imported_modules: list of rf_module = top_module.get_all_imports();
        var implicitly_used: rf_module = all_modules.first(it != top_module and it not in all_imported_modules);
        if implicitly_used != NULL then {
            error("The top module '", top_module.get_name(),
                "' does not explicitly (directly or indirectly) import some modules that it depends on, for example, '", implicitly_used.get_name(), "'");
        };
        var unused_elibs: list of rf_module = elib_tops.all(it not in all_modules);
        if not unused_elibs.is_empty() then {
            error("The top module '", top_module.get_name(),
                "' does not explicitly (directly or indirectly) import some of the given e-library top modules: ", str_join(unused_elibs.apply(it.get_name()), ", "));
        };
        
        for each (module) in all_modules do {
            // What are the elibs depending on this module?
            var depending_elib_ids: list of int = elib_modules.all_indices(module in it);
            
            if depending_elib_ids.size() <= 1 then {
                // If there are none, or just one - do nothing.
                // If exactly one elib depends on this module, we can't tell if it should be part of the elib itself,
                // or needs to be compiled into a separate elib.
                // So, we can assume that it will be a part of this elib, compiled together with it.
                // The interesting case is when the number of depending elibs is two or more.
                // In this case, it is clear that the modules on which they depend must be compiled into separate elibs.
                continue;
            };
            
            // This is the set of elibs (at least two) that depend on this module.
            var depending_elibs: list of rf_module = elib_tops.all(index in depending_elib_ids);

            // Find the elib_dependency_info struct for this set of elibs.
            // If not existing yet, create a new one.
            var elib_dep_info: elib_dependency_info = result.first(it.depending_elibs == depending_elibs);
            if elib_dep_info == NULL then {
                elib_dep_info = new with {
                    .depending_elibs = depending_elibs;
                };
                result.add(elib_dep_info);
            };
            
            // Add this module to the list of modules on which those elibs depend.
            elib_dep_info.modules.add(module);
        };

        // Now we want to remove unneeded modules from the dependency lists, and leave only 'top' modules,
        // and remove those imported by them.
        // For example, if all modules that belong to vr_ad are in the list, we will leave only vr_ad_top.
        for each (dep) in result do {
            // This list will hold modules imported by some other modules in the original list.
            var imports: list (key: it) of rf_module;
            
            // This list will hold modules NOT imported BUT used by some other modules in the original list.
            var not_imports: list (key: it) of rf_module;
            
            // Loop over all modules in the dependency list.
            for each (module) in dep.modules do {
                
                // These are all modules imported (directly or indirectly) by the given module.
                var my_imports: list of rf_module = module.get_all_imports();
                
                // These are all modules on which the given module itself depends, but does not import.
                var my_deps: list of rf_module = module.get_all_used_modules(FALSE);

                // Add imported modules to the 'imports' list.
                for each (import) in my_imports do {
                    if not imports.key_exists(import) then {
                        
                        // Here we check the following exceptional situation.
                        // It is possible that the imported module itself imports the current module.
                        // It means they are in an import cycle with each other.
                        // In this case, one of them still can be a real top (unless imported but yet another module).
                        // By checking 'module in module.get_actual_importer().get_direct_imports()',
                        // we make sure that 'module' may be a real top, and not 'import'.
                        if module not in import.get_all_imports() or module in module.get_actual_importer().get_direct_imports() then {
                            imports.add(import);
                        };
                    };
                };
                
                // Collect modules which this module uses but doesn't import.
                for each (dep) in my_deps do {
                    if not not_imports.key_exists(dep) and not imports.key_exists(dep) then {
                        not_imports.add(dep);
                    };
                };
            };
            
            // Modules which are imported by other modules are now removed from the list.
            // But if a module is used and not imported by some modules, and imported by others, it's not removed.
            // To make the removal process more efficient, we first overwrite them with NULL,
            // and then create a new list with non-NULL elements only.
            for each (module) in dep.modules do {
                if imports.key_exists(module) and not not_imports.key_exists(module) then {
                    dep.modules[index] = NULL;
                };
            };
            dep.modules = dep.modules.all(it != NULL);
        };

        for each (dep) in result do {
            // If one of the depending elibs appears also in the list of modules (depending on itself),
            // we modify the results, so it won't appear there.
            var self_dep_idx: int = dep.modules.first_index(it in dep.depending_elibs);
            if self_dep_idx != UNDEF then {
                assert self_dep_idx == dep.modules.last_index(it in dep.depending_elibs);
                var self_dep_module: rf_module = dep.modules[self_dep_idx];
                dep.modules.delete(self_dep_idx);
                
                var shorten_elib_list: list of rf_module = dep.depending_elibs.copy();
                var i: int = shorten_elib_list.first_index(it == self_dep_module);
                shorten_elib_list.delete(i);
                if not shorten_elib_list.is_empty() then {
                    var other_entry: elib_dependency_info = result.first(it.depending_elibs == shorten_elib_list);
                    if other_entry == NULL then {
                        other_entry = new with {
                            .depending_elibs = shorten_elib_list;
                        };
                        result.add(other_entry);
                    };
                    other_entry.modules.add(self_dep_module);
                };
            };
        };
        
        result = result.all(not it.modules.is_empty());
    };
    
    report_common_elibs(top_module: string, elib_tops: list of string) is {
        var elib_dependencies: list of elib_dependency_info = find_common_elibs_by_names(top_module, elib_tops);
        if elib_dependencies.is_empty() then {
            out("No dependencies are found");
        } else {
            for each (dep) in elib_dependencies do {
                out("The following e-libraries:");
                for each (elib) in dep.depending_elibs do {
                    out("\t", elib.get_full_file_name());
                };
                out("will depend on the following common module(s):");
                for each (m) in dep.modules do {
                    out("\t", m.get_full_file_name());
                };
                out("and it is adviced to create separate e-libararies from these modules");
                out();
            };
        };
    };
};

'>
