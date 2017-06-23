
~buses = [
	Bus.new('audio', 500, 1),
	Bus.new('audio', 501, 1),
	Bus.new('audio', 502, 1),
	Bus.new('audio', 503, 1),
	Bus.new('audio', 504, 1),
	Bus.new('audio', 505, 1),
];

SynthDef(\fm, { | freq = 220, vol = 0.5, outbus = 0 |
	var sig;
	sig = SinOsc.ar(freq, mul: vol);
	Out.ar(outbus, sig);
});

Synth(\fm, [\freq, 100, outbus, ~buses[0]]);

SynthDef(\spreader, { | buses = #[0,1,2,3,4,5], trig = 0 |
		var sig;
		sig = Spread(In.kr(buses));
		Out.ar([0,1], sig);
}).add;

Synth(\spreaser, [\buses, ~buses.busnum, \numbervoices]);
 s.quit;