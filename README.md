# Substrate Playground

![Echopoint SVG](https://echopoint.ujjwalvivek.com/svg/badges/custom?leftText=Javascript&badgeColor=0080ff)
![Echopoint SVG](https://echopoint.ujjwalvivek.com/svg/badges/custom?leftText=Procedural&badgeColor=ff8040&rightText=Generation)
![Echopoint SVG](https://echopoint.ujjwalvivek.com/svg/badges/custom?leftText=Engine%20Size&badgeColor=ff0080&rightText=11.3%20kB)

![Cover](cover.png)

Substrate is a tiny (~1000 LOC) vanilla JS procedural wallpaper engine. This repo is the frontend where you can visually tweak the engine's primitives (density, speed, themes, etc.) in real-time.

### Local Setup

Just serve the folder:
```bash
python -m http.server 8080
```

### Engine Usage
If you just want to *use* the engine in your own project, you don't need this repo. Just pull it from the CDN:
```javascript
import { loop, compose, primitives } from 'https://cdn.ujjwalvivek.com/scripts/substrate/latest/main.js';
```

Read the full engine documentation [here](https://cdn.ujjwalvivek.com/scripts/substrate/latest/readme.md).
