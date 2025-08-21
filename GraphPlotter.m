function GraphPlotter
  clear; clc;
  fprintf('GraphPlotter 起動\n');

  %% データ入力
  m = input('データ入力方法: 1) 手入力  2) CSVファイル選択  3) ヘルプ [既定=2] → ');
  if isempty(m), m = 2; end                                                                     % mが空なら既定値として2を採用する

  datasets = {}; names = {};

  switch m
    % 手入力
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
        nm = input('凡例名（未入力なら自動）→ ','s');
        if isempty(nm), nm = sprintf('Data%d', k); end
        names{end+1} = nm;
      end
    
    % CSVファイル選択
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
        names{end+1} = nm; % 凡例にファイル名を用いる
      end
    
    % ヘルプ表示
    case 3
      local_help();
      return;

    % ユーザーが1-3以外を選択した時
    otherwise
      error('不正な選択です。1, 2, または 3 を選んでください。');
  end

  %% モデル選択
  fprintf('\nフィットモデルを選択:\n');
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
  ttl = input('グラフのタイトル [既定="最小二乗フィット"] → ','s');                                 % タイトル設定
  if isempty(ttl), ttl = '最小二乗フィット'; end
  xlb = input('x軸ラベル [既定="x"] → ','s'); if isempty(xlb), xlb = 'x'; end                     % x軸ラベルの設定
  ylb = input('y軸ラベル [既定="y"] → ','s'); if isempty(ylb), ylb = 'y'; end                     % y軸ラベルの設定

  %% プロット準備
  fig = figure('Color','w'); hold on;
  xlabel(xlb); ylabel(ylb); title(ttl);
  grid on; grid minor;

  markers    = {'o','s','d','^','v','<','>','p','h'};
  lineStyles = {'-','--','-.',':'};
  nmark = numel(markers); nstyle = numel(lineStyles);

  legendEntries = gobjects(0);
  legendLabels  = strings(0);

  %% 各データごとにプロット＆計算
  resultsText = sprintf("=== フィット結果: %s ===\n\n", ttl);

  for k = 1:numel(datasets)                                                                     % datasetsの要素数だけ繰り返す
    x = datasets{k}{1}; y = datasets{k}{2};                                                     % k番目のデータセット,1がx座標,2がy座標
    [x,ord] = sort(x(:)); y = y(ord);                                                           % x(:)で列ベクトル化した後,sort()で昇順
    xplot = linspace(min(x), max(x), 400).';

    switch model
      % 直線
      case 1
        coef = [ones(size(x)), x] \ y;
        yhat = [ones(size(x)), x] * coef;
        yfit = [ones(size(xplot)), xplot] * coef;
        eqstr = sprintf('y = %.6g + %.6g x', coef(1), coef(2));
      % 多項式
      case 2
        p = polyfit(x,y,deg);                                                                   % polyfitで多項式近似,係数ベクトルpが返る
        yhat = polyval(p,x);
        yfit = polyval(p,xplot);
        eqstr = ['y = ' poly2str(p,'x')];
    end

    % 指標
    res  = y - yhat;                                                                            % 残差
    SSE  = sum(res.^2);                                                                         % 残差の平方和
    SST  = sum((y - mean(y)).^2);
    if SST == 0, R2 = 1; else, R2 = 1 - SSE/SST; end                                            % 決定係数の計算, データが全て同じ値の場合は1とする
    RMSE = sqrt(SSE/numel(y));                                                                  % 二乗平均平方根誤差

    % 描画（線→点）
    ls = lineStyles{mod(k-1,nstyle)+1};
    mk = markers{mod(k-1,nmark)+1};
    hfit = plot(xplot, yfit, 'k', 'LineStyle', ls, 'LineWidth', 1.6);
    hdat = scatter(x, y, 40, mk, 'MarkerEdgeColor','k', ...
                   'MarkerFaceColor','w', 'LineWidth', 1.2);

    legendEntries(end+1) = hdat; legendLabels(end+1) = sprintf('%s (Data)', names{k});
    legendEntries(end+1) = hfit; legendLabels(end+1) = sprintf('%s (Fit: %s)', names{k}, eqstr);

    % txtファイル出力
    resultsText = resultsText + sprintf("【%s】\n", names{k});
    resultsText = resultsText + sprintf("  回帰式   : %s\n", eqstr);
    resultsText = resultsText + sprintf("  決定係数  : %.6f\n", R2);
    resultsText = resultsText + sprintf("  二乗平均平方根誤差 : %.6g\n", RMSE);
    resultsText = resultsText + sprintf("  N    : %d\n\n", numel(x));
  end
  legend(legendEntries, legendLabels, 'Location','best');

  %% 保存処理
  baseDir = local_basedir();
  resultsDir = fullfile(baseDir, 'results');                                                    % fullfileはパスを連結する関数,baseDirに"results"を結合している
  if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end                                          % exist(path,'dir")は指定フォルダが存在するかチェック

  safeTitle = regexprep(ttl, '[^\w\-ぁ-んァ-ヶ一-龥（）\(\)・・、。]', '_');
  timestamp = datestr(now, 'yyyymmdd_HHMMSS');
  pngPath   = fullfile(resultsDir, sprintf('fit_%s_%s.png', safeTitle, timestamp));
  txtPath   = fullfile(resultsDir, sprintf('fit_%s_%s.txt', safeTitle, timestamp));

  % PNG 保存
  try
    exportgraphics(fig, pngPath, 'Resolution', 300);
  catch
    saveas(fig, pngPath);
  end

  % TXT 保存（UTF-8）
  fid = fopen(txtPath,'w','n','UTF-8'); fprintf(fid, '%s', resultsText); fclose(fid);

  fprintf('\nPNGファイルを保存しました → %s\n', pngPath);
  fprintf('TXTファイルを保存しました → %s\n', txtPath);
  fprintf('GraphPlotterを終了します\n')
end

%% ローカル関数
function local_help()
  fprintf('\n【ヘルプ】\n');
  fprintf('このスクリプトは、複数セットの (x,y) データを同一グラフ上で最小二乗フィットし、\n');
  fprintf('モノクロ（線種で区別）で描画します。PNG画像と結果テキストを results/ に保存します。\n\n');
  fprintf('使い方:\n');
  fprintf('  1) 手入力: データセット数→ 各セットの x, y を [1 2 3] 形式で入力。\n');
  fprintf('     凡例名は任意（未入力なら Data1 など自動）。\n');
  fprintf('  2) CSV選択: 複数のCSVを選ぶと、各ファイルの 1列目=x, 2列目=y を読み込みます。\n');
  fprintf('     凡例名はファイル名になります。\n');
  fprintf('  ※ CSVは「ヘッダ無し・数値2列」を推奨。ヘッダがあっても readmatrix が数値列を読み込みます。\n\n');
  fprintf('モデル:\n');
  fprintf('  1) 直線:    y = a + b x\n');
  fprintf('  2) 多項式:  y = Σ c_k x^k（次数を指定）\n\n');
  fprintf('描画仕様:\n');
  fprintf('  - データ点は黒枠＋白塗り、形はデータごとに変更（○, □, △, …）。\n');
  fprintf('  - フィット曲線は黒のみ、線種（実線/破線/一点鎖線/点線）でデータごとに区別。\n');
  fprintf('  - 線を先に、点を後に描画するため、線がマーカーの内側に隠れません。\n\n');
  fprintf('保存先:\n');
  fprintf('  - スクリプトと同じフォルダ直下の results/ に PNG と TXT を保存（自動作成）。\n\n');
  fprintf('補足:\n');
  fprintf('  - タイトル・軸ラベルは実行時に入力できます。\n');
  fprintf('  - R^2, RMSE, 回帰式、データ数NをTXTにまとめて保存します。\n\n');
end

function baseDir = local_basedir()
  try
    fp = mfilename('fullpath');
    if isempty(fp), baseDir = pwd; else, baseDir = fileparts(fp); end
  catch
    baseDir = pwd;
  end
end
