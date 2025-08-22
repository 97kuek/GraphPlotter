function GraphPlotter

  clear; clc;
  fprintf('<<GraphPlotter 起動>>\n');

  %% データ入力
  m = input('\n■ データ入力方法を選択\n1) 手入力  2) CSVファイル選択  3) ヘルプ [既定=2] → ');
  if isempty(m), m = 2; end

  datasets = {}; names = {};

  switch m
    case 1
      nset = input('データセット数 → ');
      validateattributes(nset, {'numeric'}, {'scalar','integer','>=',1});
      for k = 1:nset
        fprintf('\n--- データセット %d ---\n', k);
        x = str2num(input('x データ（例: [1 2 3 4]）→ ','s')); %#ok<ST2NM>
        y = str2num(input('y データ（例: [2.1 4.2 6.0 7.9]）→ ','s')); %#ok<ST2NM>
        x = x(:); y = y(:);
        assert(~isempty(x) && ~isempty(y) && numel(x)==numel(y), 'x,yが不正です。');
        datasets{end+1} = {x, y};
        names{end+1} = sprintf('Data%d', k);  % 仮の名前（後で上書き）
      end

    case 2
      [files, path] = uigetfile({'*.csv'}, 'CSVファイルを選択（複数可）', 'MultiSelect','on');
      if isequal(files,0), fprintf('キャンセルしました。\n'); return; end
      if ischar(files), files = {files}; end
      for f = 1:numel(files)
        A = readmatrix(fullfile(path,files{f}));
        assert(size(A,2) >= 2, 'CSVは2列以上の数値列が必要（1列目=x, 2列目=y）。');
        x = A(:,1); y = A(:,2);
        datasets{end+1} = {x(:), y(:)};
        [~,nm,~] = fileparts(files{f});
        names{end+1} = nm;   % 仮の凡例名（後で上書き可）
      end

    case 3
      local_help(); return;

    otherwise
      error('不正な選択です。1, 2, または 3 を選んでください。');
  end

  %% モデル選択
  fprintf('\n■ フィットモデルを選択\n');
  fprintf('  1) 直線      y = a + b x\n');
  fprintf('  2) 多項式    y = Σ c_k x^k  （次数は次で入力）\n');
  model = input('番号 [既定=1] → ');
  if isempty(model), model = 1; end
  if model == 2
    deg = input('多項式の次数 n （1以上）[既定=2] → ');
    if isempty(deg), deg = 2; end
    assert(deg>=1 && isfinite(deg), '次数 n は1以上の実数。');
  end

  %% グラフ詳細設定
  ttl = input('\n■ グラフの詳細設定\nグラフのタイトル [既定="最小二乗フィット"] → ','s');
  if isempty(ttl), ttl = '最小二乗フィット'; end
  xlb = input('x軸ラベル [既定="x"] → ','s'); if isempty(xlb), xlb = 'x'; end
  ylb = input('y軸ラベル [既定="y"] → ','s'); if isempty(ylb), ylb = 'y'; end

  %% 凡例名をここでまとめて入力
  for k = 1:numel(names)
    nm_in = input(sprintf('凡例名（既定=%s）→ ', names{k}), 's');
    if ~isempty(nm_in)
      names{k} = nm_in;
    end
  end

  %% レイアウト（下マージンを広めに確保し、タイトルは専用帯）
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

  %% マーカーの“余白感”設定
  outerSize = 90;
  innerSize = 5;

  %% 計算・描画
  resultsText = sprintf('=== フィット結果: %s ===\n\n', ttl);

  for k = 1:numel(datasets)
    x = datasets{k}{1}; y = datasets{k}{2};
    [x,ord] = sort(x(:)); y = y(ord);
    xplot = linspace(min(x), max(x), 400).';

    switch model
      case 1  % 直線 y = a + b x
        coef = [ones(size(x)), x] \ y;     % [a; b]
        yhat = [ones(size(x)), x] * coef;
        yfit = [ones(size(xplot)), xplot] * coef;
        a = coef(1); b = coef(2);
        if b >= 0
          eqstr = sprintf('y = %.6g + %.6g x', a, b);
        else
          eqstr = sprintf('y = %.6g - %.6g x', a, abs(b));
        end

      case 2  % 多項式
        p = polyfit(x,y,deg);
        yhat = polyval(p,x);
        yfit = polyval(p,xplot);
        eqstr = ['y = ' poly2str(p,'x')];  % 符号は自動整形
    end

    % 指標
    res  = y - yhat;
    SSE  = sum(res.^2);
    SST  = sum((y - mean(y)).^2);
    R2   = 1 - SSE/max(SST, eps);          % SST=0 のとき 1 扱いに近い
    RMSE = sqrt(SSE/numel(y));

    % 描画（線→点＋中央ドット）
    ls = lineStyles{mod(k-1,nstyle)+1};
    mk = markers{mod(k-1,nmark)+1};

    hfit = plot(ax, xplot, yfit, 'k', 'LineStyle', ls, 'LineWidth', 1.6);     % 計算値（線）
    hmk  = scatter(ax, x, y, outerSize, mk, 'MarkerEdgeColor','k', ...
                   'MarkerFaceColor','w', 'LineWidth', 1.4);                   % 実験値（外枠）
    hdot = plot(ax, x, y, '.', 'MarkerSize', innerSize, 'Color','k'); %#ok<NASGU>

    % 凡例（固定表記）
    legendEntries(end+1) = hmk;   legendLabels{end+1} = sprintf('%s（実験値）', names{k});
    legendEntries(end+1) = hfit;  legendLabels{end+1} = sprintf('%s（計算値: %s）', names{k}, eqstr);

    % TXT 出力用
    resultsText = [resultsText, sprintf('【%s】\n', names{k})]; %#ok<AGROW>
    resultsText = [resultsText, sprintf('  回帰式                 : %s\n', eqstr)];
    resultsText = [resultsText, sprintf('  決定係数 R^2           : %.6f\n', R2)];
    resultsText = [resultsText, sprintf('  二乗平均平方根誤差RMSE : %.6g\n', RMSE)];
    resultsText = [resultsText, sprintf('  N                      : %d\n\n', numel(x))];
  end

  legend(ax, legendEntries, legendLabels, 'Location','best', 'Interpreter','none');

  %% 保存処理
  baseDir    = local_basedir();
  resultsDir = fullfile(baseDir, 'results');
  if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end

  safeTitle = regexprep(ttl, '[^\w\-ぁ-んァ-ヶ一-龥（）\(\)・・、。]', '_');
  timestamp = datestr(now, 'yyyymmdd_HHMMSS');  % 例: 20250822_093045

  pngPath   = fullfile(resultsDir, sprintf('fit_%s_%s.png', safeTitle, timestamp));
  txtPath   = fullfile(resultsDir, sprintf('fit_%s_%s.txt', safeTitle, timestamp));

  try
    exportgraphics(fig, pngPath, 'Resolution', 300);
  catch
    saveas(fig, pngPath);
  end

  fid = fopen(txtPath,'w','n','UTF-8'); fprintf(fid, '%s', resultsText); fclose(fid);

  fprintf('\n■ 保存ファイル\nPNGファイルを保存 → %s\n', pngPath);
  fprintf('TXTファイルを保存 → %s\n', txtPath);
  fprintf('\n<<GraphPlotter 終了>>\n')
end

%% ------- ローカル関数 -------
function place_bottom_title(fig, ttl)
  % 図の下側に「専用帯」を設けてタイトルを表示（軸と独立）
  % textbox の高さを0.06、位置を下から0.08あたりに固定
  annotation(fig,'textbox',[0, 0.08, 1, 0.06], ...
    'String', ttl, 'HorizontalAlignment','center', ...
    'VerticalAlignment','middle', 'EdgeColor','none', ...
    'FontWeight','bold', 'Interpreter','none');
end

function local_help()
  fprintf('\n【ヘルプ】\n');
  fprintf('複数セットの (x,y) を最小二乗フィットし、\n');
  fprintf('・タイトルはグラフ下（専用帯）\n・実験点は中央ドット付きマーカー\n・凡例は「実験値」「計算値」表記\n');
  fprintf('で描画します。PNG/TXTを results/ に保存します。\n\n');
end

function baseDir = local_basedir()
  try
    fp = mfilename('fullpath');
    if isempty(fp), baseDir = pwd; else, baseDir = fileparts(fp); end
  catch
    baseDir = pwd;
  end
end
