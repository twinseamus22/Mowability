# MowEngine v1.8 candidate

A deterministic Swift package for the lawn-mowing recommendation engine.

Included:
- Safety state: NORMAL / CAUTION / STOP
- 100-minus-penalties Mowability score
- Non-safety score floor of 10
- Separate rain debt and fast-drying dew moisture
- Wind penalties beginning at 25 mph
- Independent gust penalties
- Heat + turf stress overlap handling
- Cold/frost/frozen turf penalties
- Personalized weekday availability
- Mowing duration + buffer requirement
- Daily recommendation based on viable contiguous window

This is an engine-only package. It intentionally excludes UI, NWS networking, widgets,
notifications, accounts, and marketplace functionality.

## Run tests

```bash
swift test
```

## Next implementation milestone

Add the NWS client and adapt hourly NWS grid/forecast data into `HourlyWeather`, then run
historical replay/regression fixtures through the same package.


## v1.8 presentation rules
- Keep 0–100 internally; present a 0.0–10.0 Mow Score.
- Use continuous red-to-green score strength, while always displaying the number.
- Describe conditions rather than prescribe behavior: “Best conditions 5–7:30 PM.”
- Lawn Tracker is separate: last mow and estimated growth never affect Mow Score.
- Tracker language: Not yet, Getting there, Getting long, Likely long.
- Safety may still label 0.0 as Unsafe conditions with the hazard reason.
