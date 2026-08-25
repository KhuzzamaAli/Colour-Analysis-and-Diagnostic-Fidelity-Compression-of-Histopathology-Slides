function huffman_rlc_batch()
    % ===== Step 1: Select Folder Interactively =====
    baseFolder = uigetdir('', 'Select Image Folder');
    if baseFolder == 0
        error('No folder was selected!');
    end

    allFiles = dir(fullfile(baseFolder, '**', '*.png'));
    if isempty(allFiles)
        allFiles = dir(fullfile(baseFolder, '**', '*.jpg'));
    end

    totalFound = length(allFiles);
    if totalFound == 0
        error('No images found in the selected folder!');
    end

    
    numImages = min(300, totalFound);
    fprintf('Found %d images. Processing Huffman & RLC Compression for %d images...\n\n', totalFound, numImages);

   
    huffmanLavgList = zeros(numImages, 1);
    huffmanCRList = zeros(numImages, 1);
    rlcRunsList = zeros(numImages, 1);
    rlcCRList = zeros(numImages, 1);

    % ===== Step 2: Loop Over Images =====
    for imgIdx = 1:numImages
        imgPath = fullfile(allFiles(imgIdx).folder, allFiles(imgIdx).name);
        imgRGB = imread(imgPath);

        % Grayscale conversion from scratch
        if size(imgRGB, 3) == 3
            img = uint8(0.2989*double(imgRGB(:,:,1)) + 0.5870*double(imgRGB(:,:,2)) + 0.1140*double(imgRGB(:,:,3)));
        else
            img = imgRGB;
        end

        [M, N] = size(img);
        totalPixels = M * N;
        originalBits = totalPixels * 8; % 8 bits per pixel baseline

        % ===== 1. Huffman Coding (From Scratch) =====
        counts = zeros(1, 256);
        for val = 0:255
            counts(val + 1) = sum(img(:) == val);
        end
        p = counts / totalPixels;
        valid_p = p(p > 0);

        probs = valid_p;
        codeLens = zeros(size(valid_p));
        nodeTree = cell(size(valid_p));
        for i = 1:length(valid_p)
            nodeTree{i} = i;
        end

        while length(probs) > 1
            [probs, idx] = sort(probs, 'ascend');
            nodeTree = nodeTree(idx);

            mergedProb = probs(1) + probs(2);

            for k = 1:length(nodeTree{1})
                codeLens(nodeTree{1}(k)) = codeLens(nodeTree{1}(k)) + 1;
            end
            for k = 1:length(nodeTree{2})
                codeLens(nodeTree{2}(k)) = codeLens(nodeTree{2}(k)) + 1;
            end

            newNode = [nodeTree{1}, nodeTree{2}];
            probs = [mergedProb, probs(3:end)];
            nodeTree = [ {newNode}, nodeTree(3:end) ];
        end

        L_huffman = sum(valid_p .* codeLens);
        huffmanTotalBits = L_huffman * totalPixels;
        CR_huffman = originalBits / huffmanTotalBits;

        % ===== 2. Run-Length Coding (RLC From Scratch) =====
        pixelVec = img(:);
        
        % Vectorized Run-Length Encoding 
        d = [1; find(pixelVec(1:end-1) ~= pixelVec(2:end)) + 1; totalPixels + 1];
        runLengths = diff(d);
        
       
        splitRuns = [];
        for r = 1:length(runLengths)
            len = runLengths(r);
            while len > 255
                splitRuns(end+1) = 255;
                len = len - 255;
            end
            splitRuns(end+1) = len;
        end

        rlcTotalBits = length(splitRuns) * 16;
        CR_rlc = originalBits / rlcTotalBits;

        
        huffmanLavgList(imgIdx) = L_huffman;
        huffmanCRList(imgIdx) = CR_huffman;
        rlcRunsList(imgIdx) = length(splitRuns);
        rlcCRList(imgIdx) = CR_rlc;
    end

    % ===== Step 3: Print Average Measured Numbers =====
    fprintf('================ AVERAGE COMPRESSION RESULTS (%d Images) ================\n', numImages);
    fprintf('1. Huffman Coding Alone:\n');
    fprintf('   - Average Code Length (L_avg): %.4f bits/pixel\n', mean(huffmanLavgList));
    fprintf('   - Average Compression Ratio (CR_Huffman): %.2f:1\n', mean(huffmanCRList));
    fprintf('   - Average Bit Saving: %.2f%%\n\n', (1 - 1/mean(huffmanCRList))*100);

    fprintf('2. Run-Length Coding (RLC) Alone:\n');
    fprintf('   - Average Number of Runs: %.0f\n', mean(rlcRunsList));
    fprintf('   - Average Compression Ratio (CR_RLC): %.2f:1\n', mean(rlcCRList));
    fprintf('=========================================================================\n');
end