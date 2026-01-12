db_path = fullfile(pwd,"mdf.db");
mdf_db = mdf_dbmanager(db_path);
%%

mdf_db = mdf_db.processFiles;



%%
'vol H:'
' Volume in drive J is HQL_Backup1 Volume Serial Number is 1851-FD28'
%%
cmdout = ' Volume in drive J is HQL_Backup1 Volume Serial Number is 1851-FD28'

%%
tokens = regexp(cmdout, '\s*Volume in drive (?<Drive>[A-Z]) is (?<Label>.*?) Volume Serial Number', 'names');
%%
tokens.Label

%%

[a,b]=mdf_init()
%%
[a,mobj2]=mdf_init()
%%

mobj2.ReadParameter('Analog Acquisition Frequency (Hz)')
%%

[k,anainfo]=mdf_readanalog(b);

%%
b.ReadParameter('Symmetric Y')
%%
b.ReadParameter('Stack Repeat Count')