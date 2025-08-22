function GraphPlotter
  % 起動
  clc; fprintf('<<GraphPlotter 起動>>\n');

  while true
    % メインメニュー
    fprintf('\n■ データ入力方法を選択\n');
    fprintf('  1) 手入力\n');
    fprintf('  2) CSVファイル選択\n');
    fprintf('  3) ヘルプ\n');
    sel = input('  [1/2/3 または q で終了] → ', 's');

    if isempty(sel)
      sel = '2';
    end
    if strcmpi(sel,'q')
      fprintf('\n<<GraphPlotter 終了>>\n'); return;
    end

    datasets = {}; names = {};

    switch str2double(sel)
      case 1  % 手入力
        nset = input_or_quit('データセット数 → ');
        validateattributes(nset, {'numeric'}, {'scalar','integer','>=',1});
        for k = 1:nset
          fprintf('\n--- データセット %d ---\n', k);
          xin = input_or_quit('x データ（例: [1 2 3 4]）→ ','s');
          yin = input_or_quit('y データ（例: [2.1 4.2 6.0 7.9]）→ ','s');
          x = str2num(xin); %#ok<ST2NM>
          y = str2num(yin); %#ok<ST2NM>
          x = x(:); y = y(:);
          assert(~isempty(x) && ~isempty(y) && numel(x)==numel(y), 'x,yが不正です。');
          datasets{end+1} = {x, y};
          names{end+1} = sprintf('Data%d', k);
        end

      case 2  % CSV入力
        [files, path] = uigetfile({'*.csv'}, 'CSVファイルを選択（複数可）', 'MultiSelect','on');
        if isequal(files,0)
          fprintf('キャンセル→メニューへ戻ります。\n');
          continue;
        end
        if ischar(files), files = {files}; end
        for f = 1:numel(files)
          A = readmatrix(fullfile(path,files{f}));
          assert(size(A,2) >= 2, 'CSVは2列以上の数値列が必要（1列目=x, 2列目=y）。');
          x = A(:,1); y = A(:,2);
          datasets{end+1} = {x(:), y(:)};
          [~,nm,~] = fileparts(files{f});
          names{end+1} = nm;
        end

      case 3  % ヘルプ
        local_help();
        continue;

        otherwise % 不正な入力
        fprintf('不正な選択です。メニューへ戻ります。\n');
        continue;
    end

    % モデル選択
    fprintf('\n■ フィットモデルを選択\n');
    fprintf('  1) 直線      y = a + b x\n');
    fprintf('  2) 多項式    y = Σ c_k x^k  （次数は次で入力）\n');
    model_in = input_or_quit('番号 [既定=1] → ','s');
    if isempty(model_in), model = 1; else, model = str2double(model_in); end
    if model == 2
      deg_in = input_or_quit('多項式の次数 n （1以上）[既定=2] → ','s');
      if isempty(deg_in), deg = 2; else, deg = str2double(deg_in); end
      assert(deg>=1 && isfinite(deg), '次数 n は1以上の実数。');
    end

    % グラフ詳細
    ttl = input_or_quit('\n■ グラフの詳細設定\nグラフのタイトル [既定="図1.1 最小二乗法"] → ','s');
    if isempty(ttl), ttl = '図1.1 最小二乗法'; end
    xlb = input_or_quit('x軸ラベル [既定="x"] → ','s'); if isempty(xlb), xlb = 'x'; end
    ylb = input_or_quit('y軸ラベル [既定="y"] → ','s'); if isempty(ylb), ylb = 'y'; end
    for k = 1:numel(names)
      nm_in = input_or_quit(sprintf('凡例名（既定=%s）→ ', names{k}), 's');
      if ~isempty(nm_in), names{k} = nm_in; end
    end
    sig_in = input_or_quit('表示する式の有効数字 桁数 [既定=3] → ','s');
    if isempty(sig_in), sig = 3; else, sig = str2double(sig_in); end
    validateattributes(sig, {'numeric'}, {'scalar','integer','>=',1,'<=',15});
    xlim_str = input_or_quit('x軸範囲 [xmin xmax]（空Enterで自動）→ ','s');
    ylim_str = input_or_quit('y軸範囲 [ymin ymax]（空Enterで自動）→ ','s');
    xlim_user = parse_range(xlim_str);
    ylim_user = parse_range(ylim_str);
    fprintf('\n■ フィット線の延長方向\n  1) 両側へ延長（既定）\n  2) 右側のみ延長\n  3) 左側のみ延長\n');
    extend_in = input_or_quit('番号 [既定=1] → ','s');
    if isempty(extend_in), extend_mode = 1; else, extend_mode = str2double(extend_in); end
    assert(ismember(extend_mode,[1 2 3]), '1/2/3 から選択してください。');

    % 描画処理
    fig = figure('Color','w');
    ax = axes('Parent',fig, 'Units','normalized', 'Position',[0.12 0.24 0.80 0.70]);
    hold(ax,'on'); grid(ax,'on'); grid(ax,'minor');
    xlabel(ax, xlb); ylabel(ax, ylb);
    place_bottom_title(fig, ttl);

    markers    = {'o','s','d','^','v','<','>','p','h'};
    lineStyles = {'-','--','-.',':'};
    nmark = numel(markers); nstyle = numel(lineStyles);

    legendEntries = gobjects(0);
    legendLabels  = {};

    outerSize = 90; innerSize = 5;

    resultsText = sprintf('=== フィット結果: %s ===\n\n', ttl);

    for k = 1:numel(datasets)
      x = datasets{k}{1}; y = datasets{k}{2};
      [x,ord] = sort(x(:)); y = y(ord);

      % フィット線 x 範囲
      xmin = min(x); xmax = max(x);
      span = max(eps, xmax - xmin);
      pad  = 0.10 * span;

      if ~isempty(xlim_user)
        switch extend_mode
          case 1, xlo = xlim_user(1); xhi = xlim_user(2);
          case 2, xlo = xmin;         xhi = xlim_user(2);
          case 3, xlo = xlim_user(1); xhi = xmax;
        end
      else
        switch extend_mode
          case 1, xlo = xmin - pad; xhi = xmax + pad;
          case 2, xlo = xmin;       xhi = xmax + pad;
          case 3, xlo = xmin - pad; xhi = xmax;
        end
      end
      if xlo == xhi, xhi = xlo + 1; end
      xplot = linspace(xlo, xhi, 400).';

      % モデル
      switch model
        case 1
          coef = [ones(size(x)), x] \ y;     % [a; b]
          yhat = [ones(size(x)), x] * coef;
          yfit = [ones(size(xplot)), xplot] * coef;
          a = coef(1); b = coef(2);
          eqstr = format_linear(a, b, sig);
        case 2
          p = polyfit(x,y,deg);
          yhat = polyval(p,x);
          yfit = polyval(p,xplot);
          eqstr = format_poly(p, 'x', sig);
      end

      % 指標
      res  = y - yhat;
      SSE  = sum(res.^2);
      SST  = sum((y - mean(y)).^2);
      R2   = 1 - SSE/max(SST, eps);
      RMSE = sqrt(SSE/numel(y));

      % 描画
      ls = lineStyles{mod(k-1,nstyle)+1};
      mk = markers{mod(k-1,nmark)+1};

      hfit = plot(ax, xplot, yfit, 'k', 'LineStyle', ls, 'LineWidth', 1.6);     % 計算値（線）
      hmk  = scatter(ax, x, y, outerSize, mk, 'MarkerEdgeColor','k', ...
                     'MarkerFaceColor','w', 'LineWidth', 1.4);                   % 実験値（外枠）
      plot(ax, x, y, '.', 'MarkerSize', innerSize, 'Color','k');                % 中央ドット

      legendEntries(end+1) = hmk;
      legendLabels{end+1}  = sprintf('%s（実験値）', names{k});
      legendEntries(end+1) = hfit;
      legendLabels{end+1}  = sprintf('%s（計算値: %s）', names{k}, eqstr);

      resultsText = [resultsText, sprintf('【%s】\n', names{k})]; %#ok<AGROW>
      resultsText = [resultsText, sprintf('  回帰式                 : %s\n', eqstr)];
      resultsText = [resultsText, sprintf('  決定係数 R^2           : %.6f\n', R2)];
      resultsText = [resultsText, sprintf('  二乗平均平方根誤差RMSE : %.6g\n', RMSE)];
      resultsText = [resultsText, sprintf('  N                      : %d\n\n', numel(x))];
    end

    legend(ax, legendEntries, legendLabels, 'Location','best', 'Interpreter','none');

    % 軸範囲の適用
    if ~isempty(xlim_user), xlim(ax, xlim_user); end
    if ~isempty(ylim_user), ylim(ax, ylim_user); end

    % 保存処理
    baseDir    = local_basedir();
    resultsDir = fullfile(baseDir, 'results');
    if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end

    safeTitle = regexprep(ttl, '[^\w\-ぁ-んァ-ヶ一-龥（）\(\)・・、。]', '_');
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');

    pngPath   = fullfile(resultsDir, sprintf('fit_%s_%s.png', safeTitle, timestamp));
    txtPath   = fullfile(resultsDir, sprintf('fit_%s_%s.txt', safeTitle, timestamp));

    try
      exportgraphics(fig, pngPath, 'Resolution', 300);
    catch
      saveas(fig, pngPath);
    end

    fid = fopen(txtPath,'w','n','UTF-8'); fprintf(fid, '%s', resultsText); fclose(fid);

    fprintf('\n■ 保存ファイル\nPNG → %s\nTXT → %s\n', pngPath, txtPath);

    % 終了/メニュー画面移行処理
    ans_end = input('\n■ 処理完了\n[Enter]でメニューに戻る / q で終了 → ','s');
    if strcmpi(ans_end,'q')
      fprintf('\n<<GraphPlotter 終了>>\n'); return;
    end
    clf(fig); close(fig);  % 次の周回に備えて閉じる
  end
end

%% 補助関数

function v = input_or_quit(prompt, mode)
  % 文字列/数値入力。'q' なら即終了
  if nargin < 2, mode = ''; end
  v = input(prompt, mode);
  if ischar(v) && strcmpi(v,'q')
    error('GraphPlotter:quit','ユーザーが終了を選択しました。');
  end
end

function rng2 = parse_range(s)
  if isempty(s), rng2 = []; return; end
  v = str2num(s); %#ok<ST2NM>
  assert(isnumeric(v) && numel(v)==2 && isfinite(v(1)) && isfinite(v(2)) && v(1) < v(2), ...
         '範囲指定は [min max] 形式で、min < max としてください。');
  rng2 = v(:).';
end

function s = format_sig(val, sig)
  % 有効数字 sig 桁を厳守し、末尾0と小数点を保持する
  % 例: val=39, sig=3 -> "39.0"
  if ~isfinite(val)
    s = sprintf('%g', val); return;
  end
  if val == 0
    if sig==1
      s = '0';
    else
      s = ['0.' repmat('0',1,sig-1)];
    end
    return;
  end
  a = abs(val);
  e = floor(log10(a));           % 10の指数
  d = sig - 1 - e;               % 小数点以下桁数
  if d >= 0
    vr = round(val, d);
    s  = sprintf(sprintf('%%.%df', d), vr);  % 固定小数（末尾0保持）
  else
    vr = round(val, d);
    s  = sprintf('%.0f', vr);               % 小数点なし
  end
end

function eq = format_linear(a, b, sig)
  aS = format_sig(a, sig);
  bS = format_sig(abs(b), sig);
  if b >= 0
    eq = sprintf('y = %s + %s x', aS, bS);
  else
    eq = sprintf('y = %s - %s x', aS, bS);
  end
end

function eq = format_poly(p, xname, sig)
  if isempty(p), eq = 'y = 0'; return; end
  deg = numel(p)-1;
  scale = max(1, max(abs(p)));
  tol = 10^(-sig) * scale;  % 有効数字に応じた 0 判定

  terms = {};
  for k = 1:numel(p)
    coef = p(k);
    pow  = deg - (k-1);
    if abs(coef) < tol, continue; end

    absCoef = abs(coef);
    cS = format_sig(absCoef, sig);

    if pow == 0
      t = cS;
    elseif pow == 1
      if abs(absCoef-1) < tol
        t = xname;
      else
        t = sprintf('%s %s', cS, xname);
      end
    else
      if abs(absCoef-1) < tol
        t = sprintf('%s^%d', xname, pow);
      else
        t = sprintf('%s %s^%d', cS, xname, pow);
      end
    end

    if isempty(terms)
      if coef < 0, terms{end+1} = ['-' t]; else, terms{end+1} = t; end %#ok<AGROW>
    else
      if coef < 0, terms{end+1} = [' - ' t]; else, terms{end+1} = [' + ' t]; end %#ok<AGROW>
    end
  end

  if isempty(terms), eq = 'y = 0'; else, eq = ['y = ' strjoin(terms,'')]; end
end

function place_bottom_title(fig, ttl)
  annotation(fig,'textbox',[0, 0.08, 1, 0.06], ...
    'String', ttl, 'HorizontalAlignment','center', ...
    'VerticalAlignment','middle', 'EdgeColor','none', ...
    'FontWeight','bold', 'Interpreter','none');
end

function local_help()
  fprintf('\n【ヘルプ】\n');
  fprintf('複数セットの (x,y) を最小二乗フィットして描画します。\n');
  fprintf('・タイトルはグラフ下（専用帯）\n・実験点は中央ドット付きマーカー\n・凡例は「実験値」「計算値」\n');
  fprintf('・軸範囲は [min max] 指定（空で自動）\n・回帰式は有効数字で表示（末尾0保持）\n');
  fprintf('・フィット線は 両側/右のみ/左のみ の延長が可能\n');
  fprintf('・PNG/TXTを results/ に保存します。\n');
  fprintf('・メニューで q を押すと終了します。\n\n');
end

function baseDir = local_basedir()
  try
    fp = mfilename('fullpath');
    if isempty(fp), baseDir = pwd; else, baseDir = fileparts(fp); end
  catch
    baseDir = pwd;
  end
end
