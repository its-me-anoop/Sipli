"""Original 26-second ambient cue. No sampled or third-party audio."""
import math, wave, array, random
from pathlib import Path
rate=44100; duration=26; random.seed(41)
notes=[60,64,67,71,57,60,64,67,53,57,60,64,55,59,62,67]
result=array.array('h')
for i in range(rate*duration):
    t=i/rate
    fade=min(1,t/1.5,(duration-t)/2.0)
    chord=int(t/4)%4
    pad=0.0
    for note in [notes[chord*4],notes[chord*4+1],notes[chord*4+2]]:
        hz=440*2**((note-69)/12)
        pad+=0.035*(math.sin(2*math.pi*hz*t)+0.3*math.sin(2*math.pi*hz*1.002*t))
    step=int(t/0.5); age=t-step*0.5
    hz=440*2**((notes[(step//8%4)*4+step%4]+12-69)/12)
    bell=0.10*math.exp(-age*8)*(math.sin(2*math.pi*hz*age)+0.15*math.sin(2*math.pi*hz*2.004*age))
    beat=t%1.0
    pulse=0.07*math.exp(-beat*18)*math.sin(2*math.pi*(55*beat+3*(1-math.exp(-beat*25))))
    s=(pad+bell+pulse)*fade*2.0
    for gain in [1+0.06*math.sin(t*0.7),1-0.06*math.sin(t*0.7)]:
        result.append(int(max(-1,min(1,s*gain))*32767))
with wave.open(str(Path(__file__).with_name('soundtrack.wav')),'wb') as f:
    f.setnchannels(2);f.setsampwidth(2);f.setframerate(rate);f.writeframes(result.tobytes())
print('Original stereo soundtrack written')
