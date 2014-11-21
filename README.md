scripts
=======

Oracle log parser
=================
* err_srch.pl
* err_srch.cfg

This script is run against oracle log file and depending on the configured settings
in the INCLUDE/EXCLUDE sections of the config file looks for specific entries in the log
and alerts via email somebody on match.
Since it was run in a production environment via crontab, where log file is rotated
not that often, there's a seek logic, so each time you run the script against the log,
it will check only the new records /keeping position information in a seek file/.
Some sort of logwatcher for ORACLE.
