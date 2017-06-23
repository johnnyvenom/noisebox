fork{

	SynthDef(\test, {
		var sig = Array.fill(10);
		var input = Array.fill(10);
		
		10.do({ arg count; 
			var lo, hi; 
			lo = count + 1 * 20;
			hi = lo * 2;
			input[count] = count * 10 + 100; 
			sig[count] = SinOsc.ar(In.kr(input[count]).range(lo, hi), mul: 0.1);
			postf("Added: Voice %; Input bus: %; Range: lo: %, hi: %\n", sig[count], input[count], lo, hi);
			
			Out.ar([0, 1], sig[count]);
			});
	}).add;

	s.sync;

	Synth(\test);

}