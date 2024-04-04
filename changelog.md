v0.1.4:
+ Add configuration editor (-C)
+ Add cmdline additions/removals (-A + -R)
+ Add presets (/lib/stubload/presets)
+ Fix duplicate '--config' arguments (--edit_config + --config)
+ Fix entry identification
+ Add prompt option
+ Move all configuration stuff (-> lib/config.sh)
+ Add manpage (stubload(1))
+ Fix not being able to find mountpoint of subdirectories (grep -> df)
+ Add support for multiple ramdisks

v0.1.3:
+ Improve argument parsing method (again) & general code
+ Add script functionality
+ Remove sudo option
+ Merge 'verbose' & 'debug' options
+ Fix wrong `tput` command causing colour to not change back to default
+ Remove colour option
+ Add support for sd* disk mapping
+ Add entry number selection option
+ Add configuration file chooser
+ Remove debugging
