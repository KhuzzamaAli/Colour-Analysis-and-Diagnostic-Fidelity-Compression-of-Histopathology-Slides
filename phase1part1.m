function main()
    % 1. ?????? ?????? ???????? ?? ??? ????????
    selectedFolder = uigetdir('', 'Select Image Folder');
    if selectedFolder == 0
        error('No folder selected!');
    end
    
    % ???? ????? ??? ??? Desktop
    desktop_path = fullfile(getenv('USERPROFILE'), 'Desktop');
    output_folder = fullfile(desktop_path, 'Phase1_Channel_Outputs');
    if ~exist(output_folder, 'dir'), mkdir(output_folder); end

    % 2. ?????? ????? (Step 1: Verification)
    fprintf('=== Step 1: Verifying Round-Trip Accuracy ===\n');
    test_rgb = rand(32, 32, 3);
    err = round_trip_error(test_rgb);
    fprintf('CMY Max Abs Error: %e\n', err.cmy);
    fprintf('HSI Max Abs Error: %e\n', err.hsi);
    fprintf('LAB Max Abs Error: %e\n\n', err.lab);

    % 3. ????? ?? ????? ?? ?????? ???????
    image_files = dir(fullfile(selectedFolder, '**', '*.png'));
    if isempty(image_files)
        image_files = dir(fullfile(selectedFolder, '**', '*.jpg')); 
    end

    if isempty(image_files)
        fprintf('Warning: No images found in selected directory.\n');
        return;
    end

    % 4. ????? 300 ???? ??? ???? ?????????
    fprintf('=== Step 2: Processing Images & Separating Channels ===\n');
    num_to_process = min(300, length(image_files)); 

    for k = 1:num_to_process
        full_path = fullfile(image_files(k).folder, image_files(k).name);
        img_rgb = im2double(imread(full_path));
        [~, fname, ~] = fileparts(image_files(k).name);

        % --- HSI ---
        hsi = rgb_to_hsi(img_rgb);
        imwrite(mat2gray(hsi(:,:,1)), fullfile(output_folder, [fname '_HSI_H_Hue.png']));
        imwrite(hsi(:,:,2), fullfile(output_folder, [fname '_HSI_S_Sat.png']));
        imwrite(hsi(:,:,3), fullfile(output_folder, [fname '_HSI_I_Int.png']));

        % --- CMY ---
        cmy = rgb_to_cmy(img_rgb);
        imwrite(cmy(:,:,1), fullfile(output_folder, [fname '_CMY_C.png']));
        imwrite(cmy(:,:,2), fullfile(output_folder, [fname '_CMY_M.png']));
        imwrite(cmy(:,:,3), fullfile(output_folder, [fname '_CMY_Y.png']));

        % --- CIE L*a*b* ---
        lab = rgb_to_lab(img_rgb);
        imwrite(lab(:,:,1)/100, fullfile(output_folder, [fname '_LAB_L.png'])); 
        imwrite(mat2gray(lab(:,:,2)), fullfile(output_folder, [fname '_LAB_a.png'])); 
        imwrite(mat2gray(lab(:,:,3)), fullfile(output_folder, [fname '_LAB_b.png'])); 
    end

    fprintf('Done processing %d images! Saved to: %s\n', num_to_process, output_folder);
end

% =========================================================================
% HELPER FUNCTIONS (?????? ????????)
% =========================================================================

function err = round_trip_error(rgb)
    err.cmy = max(abs(rgb(:) - reshape(cmy_to_rgb(rgb_to_cmy(rgb)), [], 1)));
    err.hsi = max(abs(rgb(:) - reshape(hsi_to_rgb(rgb_to_hsi(rgb)), [], 1)));
    err.lab = max(abs(rgb(:) - reshape(lab_to_rgb(rgb_to_lab(rgb)), [], 1)));
end

function cmy = rgb_to_cmy(rgb), cmy = 1.0 - rgb; end
function rgb = cmy_to_rgb(cmy), rgb = 1.0 - cmy; end

function hsi = rgb_to_hsi(rgb)
    EPS = 1e-8; r = rgb(:,:,1); g = rgb(:,:,2); b = rgb(:,:,3);
    num = 0.5 * ((r - g) + (r - b));
    den = sqrt((r - g).^2 + (r - b).*(g - b)) + EPS;
    theta = acos(min(max(num ./ den, -1.0), 1.0));
    h = theta; h(b > g) = 2 * pi - theta(b > g); h = h / (2 * pi);
    s = 1.0 - 3.0 * min(min(r, g), b) ./ (r + g + b + EPS);
    i = (r + g + b) / 3.0;
    hsi = cat(3, h, s, i);
end

function rgb = hsi_to_rgb(hsi)
    EPS = 1e-8;
    h = hsi(:,:,1) * 2 * pi; s = hsi(:,:,2); i = hsi(:,:,3);
    [rows, cols, ~] = size(hsi);
    out = zeros(rows, cols, 3);

    m1 = h < (2 * pi / 3);
    hh = h(m1);
    b1 = i(m1) .* (1 - s(m1));
    r1 = i(m1) .* (1 + s(m1) .* cos(hh) ./ (cos(pi / 3 - hh) + EPS));
    g1 = 3 * i(m1) - (r1 + b1);

    m2 = (h >= (2 * pi / 3)) & (h < (4 * pi / 3));
    hh = h(m2) - 2 * pi / 3;
    r2 = i(m2) .* (1 - s(m2));
    g2 = i(m2) .* (1 + s(m2) .* cos(hh) ./ (cos(pi / 3 - hh) + EPS));
    b2 = 3 * i(m2) - (r2 + g2);

    m3 = h >= (4 * pi / 3);
    hh = h(m3) - 4 * pi / 3;
    g3 = i(m3) .* (1 - s(m3));
    b3 = i(m3) .* (1 + s(m3) .* cos(hh) ./ (cos(pi / 3 - hh) + EPS));
    r3 = 3 * i(m3) - (g3 + b3);

    r_chan = zeros(rows, cols); g_chan = zeros(rows, cols); b_chan = zeros(rows, cols);
    r_chan(m1) = r1; g_chan(m1) = g1; b_chan(m1) = b1;
    r_chan(m2) = r2; g_chan(m2) = g2; b_chan(m2) = b2;
    r_chan(m3) = r3; g_chan(m3) = g3; b_chan(m3) = b3;

    out(:,:,1) = r_chan; out(:,:,2) = g_chan; out(:,:,3) = b_chan;
    rgb = min(max(out, 0.0), 1.0);
end

function M = get_M_RGB2XYZ()
    M = [0.4124564, 0.3575761, 0.1804375; ...
         0.2126729, 0.7151522, 0.0721750; ...
         0.0193339, 0.1191920, 0.9503041];
end

function lin = srgb_to_linear(c)
    lin = zeros(size(c)); mask = c <= 0.04045;
    lin(mask) = c(mask) / 12.92; lin(~mask) = ((c(~mask) + 0.055) / 1.055) .^ 2.4;
end

function srgb = linear_to_srgb(c)
    c = max(c, 0); srgb = zeros(size(c)); mask = c <= 0.0031308;
    srgb(mask) = 12.92 * c(mask); srgb(~mask) = 1.055 * (c(~mask) .^ (1 / 2.4)) - 0.055;
end

function xyz = rgb_to_xyz(rgb)
    lin = srgb_to_linear(rgb); M = get_M_RGB2XYZ(); [r, c, ch] = size(lin);
    xyz = reshape(reshape(lin, [], ch) * M', r, c, ch);
end

function rgb = xyz_to_rgb(xyz)
    M = inv(get_M_RGB2XYZ()); [r, c, ch] = size(xyz);
    lin = reshape(reshape(xyz, [], ch) * M', r, c, ch);
    rgb = min(max(linear_to_srgb(lin), 0.0), 1.0);
end

function val = f_func(t)
    delta = 6 / 29; val = zeros(size(t)); mask = t > delta^3;
    val(mask) = nthroot(t(mask), 3); val(~mask) = t(~mask) / (3 * delta^2) + 4 / 29;
end

function val = finv_func(t)
    delta = 6 / 29; val = zeros(size(t)); mask = t > delta;
    val(mask) = t(mask) .^ 3; val(~mask) = 3 * delta^2 * (t(~mask) - 4 / 29);
end

function lab = rgb_to_lab(rgb)
    white = reshape([0.95047, 1.00000, 1.08883], 1, 1, 3);
    xyz = rgb_to_xyz(rgb) ./ white;
    fx = f_func(xyz(:,:,1)); fy = f_func(xyz(:,:,2)); fz = f_func(xyz(:,:,3));
    lab = cat(3, 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
end

function rgb = lab_to_rgb(lab)
    white = reshape([0.95047, 1.00000, 1.08883], 1, 1, 3);
    fy = (lab(:,:,1) + 16) / 116; fx = fy + lab(:,:,2) / 500; fz = fy - lab(:,:,3) / 200;
    xyz = cat(3, finv_func(fx), finv_func(fy), finv_func(fz)) .* white;
    rgb = xyz_to_rgb(xyz);
end