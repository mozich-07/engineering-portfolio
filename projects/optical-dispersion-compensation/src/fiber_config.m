function c = fiber_config()
% FIBER_CONFIG Reproducible symbol-rate coherent baseband experiment.
c.symbolRate = 32e9; c.wavelength = 1550e-9;
c.D = 17;                         % ps/(nm km)
c.beta2 = -(c.D*1e-6)*c.wavelength^2/(2*pi*299792458); % s^2/m
c.lengthKm = 80; c.assumedLengthKm = 60;
c.nSymbols = 2048; c.guard = 512;
c.trainBlocks = 24; c.valBlocks = 8; c.testBlocks = 24;
c.trainSnr = 18; c.testSnrs = [12 16 18 20 24];
c.windows = [1 3 7 15 31 63];
c.lambdas = [0 1e-5 1e-3 0.01 0.1];
c.trainSeed = 10000; c.valSeed = 20000; c.testSeed = 30000;
c.version = '1.0';
end
