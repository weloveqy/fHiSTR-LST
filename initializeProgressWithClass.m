function progressTracker = initializeProgressWithClass(mm, totalPoints)
    progressTracker = struct();
    progressTracker.q = parallel.pool.DataQueue;
    progressTracker.count = 0;
    progressTracker.total = totalPoints;
    progressTracker.nextUpdate = 0.01; % 1% interval
    progressTracker.mm = mm;
    
    % Use atomic manipulation to ensure accurate counting
    progressTracker.lock = parallel.pool.DataQueue;
    progressTracker.realCount = 0;
    
    % Callback function (shows current category)
    function updateProgress(~)
        send(progressTracker.lock, 1);
        progressTracker.realCount = progressTracker.realCount + 1;
        currentCount = progressTracker.realCount;
        
        currentProgress = currentCount / progressTracker.total;
        if currentProgress >= progressTracker.nextUpdate
            fprintf('Classtype %d progress: %.1f%% (%d/%d)\n', ...
                progressTracker.mm, ...
                min(currentProgress*100, 100), ... % Make sure it does not exceed 100%
                min(currentCount, progressTracker.total), ...
                progressTracker.total);
            
            progressTracker.nextUpdate = progressTracker.nextUpdate + 0.01;
        end
    end
    
    afterEach(progressTracker.q, @updateProgress);
end