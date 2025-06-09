function net = configureNetwork(~, ~, trainFcn, hiddenLayerSize)  % 定义网络配置函数
    net = fitnet(hiddenLayerSize, trainFcn);
    net.input.processFcns = {'removeconstantrows','mapminmax'};
    net.output.processFcns = {'removeconstantrows','mapminmax'};
    net.divideFcn = 'dividerand';
    net.divideMode = 'sample';
    net.divideParam.trainRatio = 0.75;
    net.divideParam.valRatio = 0.25;
    net.divideParam.testRatio = 0;
    net.performFcn = 'mse';
    net.trainParam.showWindow = false;
end