stack = mdfExtractLoader("G:\tmp\00_igkl\hql090\zstack\HQL090_whiskerb251020_001");
ch1_stack = stack.loadstack("ch1");
%%
motion_stack = ch1_stack(:,:,60:end);
vertices = mdf_rectangle_polygon(motion_stack,'rectangle');
%%
motion_stack = ch1_stack(:,:,60:end);
motion_table = pre_estimatemotion(motion_stack,motion_stack(:,:,1),vertices,true);
corrected_stack = pre_applymotion(motion_stack,motion_table);
%%
ch2_stack = stack.loadstack("ch2");
motion_stack = ch2_stack(:,:,50:end);
corrected_stack = pre_applymotion(motion_stack,motion_table);


%%
io_postsavetiff(corrected_stack,"G:\tmp\00_igkl\hql090\zstack\HQL090_whiskerb251020_001ch2corr.tif",[0.57,0.57,1])