//---------------------------------------------------
// File name   : README
// Project     : Share/AEWare
// Developers  : Yuri Tsoglin, Ron Pluth, Cadence Design Systems
// Created     : Tue Oct 6 18:53:27 GMT 2014
// Description : Specman dependency utility (finds top import files and analyses dependencies)
// Notes       : Load ia_top.e or compile it into Specman, then use the commands:
//             : gen; sys.import_analyzer.ia_visualize("<your-top-module>")
// --------------------------------------------------
// Copyright 2014 (c) Cadence Design Systems
// --------------------------------------------------

Introduction
============
In order to compile packages/a number of files into an e-library (elib), it's important
to ensure that each elib does not contain duplicate definitions. This can happen
if some code imports some common code, and if this common code is imported elsewhere too.
If two or more elibs contain some common module inside them which is not compiled 
into a separate elib, those elibs cannot be linked together.

In loading mode, or when compiling all files at once, this doesn't matter, since SN
recognizes duplicate imports. However, in the elib flow this can lead to issues
of duplicate imports.

Flow
====
The general idea of this utility is as follows:
0) load or compile your e code with the following setting 
   enabled: set_config(misc,lint_mode,TRUE)
1) find potential top modules which can be compiled into an elib
2) find out if there are any common modules between the potential elibs

Details
=======

1 Finding potential top modules/files
+++++++++++++++++++++++++++++++++++++
- import_analyzer.analyze_imports() [in ia.e] 
      + will find all top modules. "top module" is a file that imports other files 
        in its directory, but is not imported by any others in its own directory
      + called in post_generate() of sys if ia.e is loaded

- Use the "show packages" command or the reflection method 
  rf_manager.get_all_loaded_erm_packages()
      + if you code is complying the UVM-e guidelines, the above utilities will show 
        you the existing UVM packages and their names
      + the names of the packages can be passed (as list of string) to
        the depdendency methos (described in 2)


2 Report dependencies
+++++++++++++++++++++
- lint_manager.report_common_elibs(<top_module>,<list of elib_tops>) [in find_elib_dependencies.e]
      + has two parameters of type string:
        top_module - the top module of the environment (usually imported by the top 
                     config file or by test files)
        elib_tops  - a list of potential e-lib top modules (derived from step 1)
      + The method creates a report suggesting which common top modules are used 
        by which elibs, and you are advised to compiled those into separate 
        elibs.
      + report_common_elibs calls find_common_elibs_by_names(), which calls 
        find_common_elibs() which does the actual work
 

3 Additional points to consider
+++++++++++++++++++++++++++++++
If something is used but not explicitly imported, you will not necessarily get a 
dependency on the top file of the package being used. For example, assume that 
your top file imports vr_ad_top, and then imports two uvcs. Those two uvcs use 
vr_ad, but don't import it explicitly. (It's a bad situation, but it happens).

In this case, the utility won't necessarily give you the file name "vr_ad_top". 
Instead, it might give one or more other files that are part of the vr_ad package. 
For example, if your code uses some entity (field, method, macro, etc.) declared 
in file "vr_ad_api.e", you might get that one. Then it's up to you to use common 
sense and decide what you actually want to compile into common elibs. If you get 
some vr_ad files, you will probably decide to use vr_ad_top.

Also, some of the found common elibs can themselves depend on more common elibs. 
You will need to use the utility again on those to figure that out. For example, 
let's assume that some of your packages use several different VIP packages. If 
you decide to compile those again into several elibs (one per VIP), they all 
will depend on the VIP common package (such as cdn_e_utils), so you'll need to 
discover that, too.



4 High-level description of lint_manager.report_common_elibs
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Usage relation between modules is determined by two factors:
 + "import" statements in the code:  A module explicitly uses another module, 
   if it imports it directly or indirectly.
 + Actual usages of entities declared in another module: A module implicitly 
   uses another module, if it uses (refers to) some named entities (e.g., types) 
   declared in the other module.

For each elib top module passed via the elib_tops list, we find all the modules 
which that module uses. We also find all the modules which top_module uses, i.e., all 
relevant modules. Explicit usages are found using the reflection get_direct_imports() 
method. Implicit usages are found using the entity_reference API.

Now we "classify" all modules into groups, such that each group of modules is commonly 
used by a group of two or more elibs. For each module, we determine which 
elibs use that module. (If there are more than one - we consider it as part of 
that elib itself). All modules that have exactly the same group of depending 
elibs, are grouped together.

Once we got a list of elib_dependency_info structures, i.e., the pairs of (elibs 
list <-> used modules list), we refine the modules list, so it will only contain the 
top modules, not explicitly imported. For example, if some group of elibs is found 
to use modules A_top, A_1, A_2, B_top, and B_1, but A_1 and A_2 are explicitly imported 
by A_top, and B_1 is explicitly imported by B_1, we will remain with just A_top, B_top.


5 Visualization
+++++++++++++++
User can use import_analyzer.ia_visualize(top:string) to create a small GUI which
lists all potential top modules. If you import ia_top.e, import_analyzer.analyze_imports()
will be called in post generate, and the potential tops are stored in import_analyzer.tops
Note: you will need to run in GUI mode if you want visualization

You can then call import_analyzer.ia_visualize(top:string). The top argument is the top
module of your verification environment (file you load in top config or in your tests).
import_analyzer.ia_visualize() creates a window which lists the potential top modules
for consideration as elib import files. You can select which ones you would like
to make into an elib and click "Analyze Selected Tops". This will call 
lint_manager.report_common_elibs() with the selected arguments and present the result
in the Specman console (and log file).
