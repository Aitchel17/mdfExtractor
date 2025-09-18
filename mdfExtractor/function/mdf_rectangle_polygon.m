function [vertices, ref_slice] = mdf_rectangle_polygon(stack, roi_type, preexistingvertices)
% ROI_RECTANGLE_POLYGON (grayscale + imshow)
%  - 입력: HxWxN 그레이스케일 스택, roi_type: 'rectangle' | 'polygon'
%  - sliceViewer 없이 uiaxes + imshow로 표시/제어
%  - 대비: Min/Max uislider -> axes.CLim 조정
%
% 출력:
%  vertices : ROI 꼭짓점 좌표 (Nx2). rectangle은 4꼭짓점으로 변환해 반환
%  ref_slice: ROI를 확정한 슬라이스 인덱스

    if nargin < 3
        preexistingvertices = [];
    end
    assert(ndims(stack)==3, 'stack must be HxWxN grayscale.');

    % 슬라이스 개수/초기값
    nSlices  = size(stack,3);
    curSlice = 1;

    % 데이터 범위(모든 프레임 통합) → 슬라이더 Limits/초기값으로 사용
    dataMin = double(min(stack,[],'all'));
    dataMax = double(max(stack,[],'all'));
    if dataMax <= dataMin
        dataMax = dataMin + 1;
    end

    % ===== UI 구성 =====
    fig = uifigure('Name','Stack Explorer','Position',[100 100 800 600]);

    main = uigridlayout(fig,[2,1]);
    main.RowHeight   = {'1x','fit'};
    main.ColumnWidth = {'1x'};
    main.Padding     = [6 6 6 6];
    main.RowSpacing  = 6;

    % 이미지 패널
    imgPanel = uipanel(main,'Title','Slice Viewer');
    imgPanel.Layout.Row = 1; imgPanel.Layout.Column = 1;

    imgGL = uigridlayout(imgPanel,[1,1], ...
        'Padding',[0 0 0 0], 'RowSpacing',0, 'ColumnSpacing',0);
    ax = uiaxes(imgGL); ax.Layout.Row = 1; ax.Layout.Column = 1;
    ax.Toolbar.Visible = 'off'; disableDefaultInteractivity(ax);
    axis(ax,'image'); axis(ax,'off');

    % 콘솔 패널
    ctrl = uipanel(main,'Title','Console');
    ctrl.Layout.Row = 2; ctrl.Layout.Column = 1;

    ctrlGL = uigridlayout(ctrl,[2,1], 'Padding',[8 8 8 8], 'RowSpacing',8);
    ctrlGL.RowHeight   = {'fit','fit'};
    ctrlGL.ColumnWidth = {'1x'};

    % 대비 슬라이더
    intPanel = uipanel(ctrlGL,'Title','Intensity');
    intPanel.Layout.Row = 1;
    gi = uigridlayout(intPanel,[2 2], 'ColumnWidth',{110,'1x'}, 'RowSpacing',6, 'Padding',[6 6 6 6]);

    uilabel(gi,'Text','Min Intensity:','HorizontalAlignment','left');
    minSld = uislider(gi,'Limits',[dataMin dataMax],'Value',dataMin);

    uilabel(gi,'Text','Max Intensity:','HorizontalAlignment','left');
    maxSld = uislider(gi,'Limits',[dataMin dataMax],'Value',dataMax);

    % 슬라이스/버튼
    slPanel = uipanel(ctrlGL,'Title','Slice / Actions'); slPanel.Layout.Row = 2;
    gs = uigridlayout(slPanel,[2 3], ...
        'RowHeight',{'fit','fit'}, 'ColumnWidth',{'1x','fit','fit'}, 'RowSpacing',6, 'Padding',[6 6 6 6]);

    sliceLbl = uilabel(gs,'Text',sprintf('Slice: %d / %d',curSlice,nSlices), ...
        'HorizontalAlignment','left');
    sliceLbl.Layout.Row = 1; sliceLbl.Layout.Column = [1 3];

    sliceSld = uislider(gs, 'Limits', [1 max(1,nSlices)], 'Value', curSlice, ...
        'MajorTicks', round(linspace(1, max(1,nSlices), min(6, max(1,nSlices)))) );
    sliceSld.Layout.Row = 2; sliceSld.Layout.Column = 1;

    uibutton(gs,'Text','Reset','ButtonPushedFcn',@(~,~)resetROI());
    uibutton(gs,'Text','Confirm','ButtonPushedFcn',@(~,~)uiresume(fig));

    % ===== 초기 표시 =====
    imH = imshow(stack(:,:,curSlice), [], 'Parent', ax, 'InitialMagnification','fit');
    ax.CLim = [minSld.Value maxSld.Value];

    % ===== ROI 초기화 =====
    theROI = drawROI();
    resetFlag = false;

    % ===== 콜백 연결 =====
    minSld.ValueChangedFcn = @(s,~)updateIntensity();
    maxSld.ValueChangedFcn = @(s,~)updateIntensity();
    sliceSld.ValueChangingFcn = @(s,e)updateSlice(round(e.Value));
    sliceSld.ValueChangedFcn  = @(s,~)updateSlice(round(s.Value));

    % ===== UI 루프 =====
    while true
        uiwait(fig);
        if ~isvalid(fig), break; end
        if resetFlag
            resetFlag = false;
            continue;
        end
        break;
    end

    % ===== 결과 반환 =====
    vertices = round(theROI.Position);
    if strcmpi(roi_type,'rectangle')
        x1 = vertices(1); y1 = vertices(2);
        x2 = x1 + vertices(3); y2 = y1 + vertices(4);
        vertices = [x1, y1; x2, y1; x2, y2; x1, y2];
    end
    ref_slice = curSlice;

    if isvalid(fig), close(fig); end

    % ---------- 중첩 함수 ----------
    function updateIntensity()
        lo = min(minSld.Value, maxSld.Value);
        hi = max(minSld.Value, maxSld.Value);
        minSld.Value = lo; maxSld.Value = hi;
        if isvalid(ax), ax.CLim = [lo hi]; end
    end

    function updateSlice(k)
        if k < 1 || k > nSlices, return; end
        curSlice = k;
        sliceLbl.Text = sprintf('Slice: %d / %d',curSlice,nSlices);
        if isvalid(imH), imH.CData = stack(:,:,curSlice); end
    end

    function roi = drawROI()
        if ~isempty(preexistingvertices)
            switch lower(roi_type)
                case 'rectangle', roi = drawrectangle(ax,'Position',preexistingvertices);
                case 'polygon',   roi = drawpolygon(  ax,'Position',preexistingvertices);
                otherwise, error('Unsupported ROI type: %s (use rectangle|polygon)', roi_type);
            end
        else
            switch lower(roi_type)
                case 'rectangle', roi = drawrectangle(ax);
                case 'polygon',   roi = drawpolygon(ax);
                otherwise, error('Unsupported ROI type: %s (use rectangle|polygon)', roi_type);
            end
        end
    end

    function resetROI()
        if isvalid(theROI), delete(theROI); end
        theROI = drawROI();
        resetFlag = true;
        uiresume(fig);
    end
end
