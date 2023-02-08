# RadonSim

A script written in Matlab/Octave, utilizing data obtained from the Airthings Wave Air Quality Monitor and supplementary ventilation data input by the user, is employed to analyze the behavior of radon gas within specific rooms. Through the utilization of this data, a ventilation pattern is proposed to **significantly reduce the risk of lung cancer**.

***This program is part of a work in progress. I will provide the reference for citation as soon as we publish it.***

Ángel Rodés, 2022 \
[www.angelrodes.com](https://www.angelrodes.com/)

## How to use

### Get radon data

1. Follow the instructions from your Airthings Wave Plus monitor to set up the app on your phone. Create a new account if you don't have one.
2. After a few hours, you can log in and see your data online at [dashboard.airthings.com](https://dashboard.airthings.com/)
3. Download your data by clicking "Export to CSV": \
![image](https://user-images.githubusercontent.com/53089531/191995763-0887d323-0b59-41bb-aa67-84ccd3095d4e.png)

### Create ventilation data

1. Use the template ```Air-ventilation-template.xlsx``` in the spreadsheet to record when you open or close the window in the room.
2. Using the same spreadsheet, create the csv air-circulation file. Note the format in the example given and make sure you are using the same time zone as in the radon data file, usually [UTC](https://en.wikipedia.org/wiki/Coordinated_Universal_Time).

### Fit the model and plot your data

1. Run the file ```RadonSim_v2.m``` in Matlab/Octave. 

> If you are using Linux and you have Octave installed, you can just run this in your terminal:

```bash
wget -O - https://raw.githubusercontent.com/angelrodes/RadonSim/main/RadonSim_v2.m | octave
```
The script will ask for the CSV files. Two files are given as examples:

* Radon data file: ```2930129618-latest(20221121).csv```
* Air circulation file: ```Office217.csv```

## Output

![Screenshot at 2023-01-15 14-29-24](https://user-images.githubusercontent.com/53089531/212543552-89833092-6141-4697-a2be-4b1f34995234.png)

The radon data provided by the device is depicted by a thick black line.

The ventilation pattern is drawn in blue at the top of the figure.

The script calculates and plots the 1h-recorded Radon data from the 24h-average data provided by the device. These data are used to calculate and plot (in light grey) the 3h average. See below for an explanation of the short-term data.

The main purpose of the script is to fit a simple model to calculate the following parameters:

* Maximum Radon concentration (Bq/m3) room is not ventilated for a long time.
* Minimum Radon concentration (Bq/m3) If the room is well-ventilated.
* Ventilation rate (Bq/m3/h). The speed at which the Radon is eliminated when the air is circulating in the room.
* Accumulation rate (Bq/m3/h). The speed at which the Radon accumulates in the room when the windows are closed.

This model is fitted to the data using a converging Mote-Carlo inverse-modeling method using a similar approach as in [Rodés *et al.* (2014)](https://doi.org/10.1016/j.quageo.2013.10.002).

The best fitting model is depicted in blue. Magenta line represents the 24h average corresponding to the same model.

Best-fitting parameters and one-sigma ranges are displayed in the text output, together with some useful (and very simplified) information: 

* How much time do we need to ventilate to flush the Radon in the room?
* After ventilating and closing the window, how much time we can stay in the room with Radon concentrations [below 300 Bq/m3](https://www.who.int/data/gho/indicator-metadata-registry/imr-details/5618)?

Example text output:

```
Fitting results and [one sigma range]:
    Reduced chi-squared: [2.4-3.4]
    N models in 1-sigma: 595 of 5000
    [Rn]min: 89.5 [71.2-95.7] Bq/m3
    [Rn]max: 957 [796-1.2e+03] Bq/m3
    Ventilation  rate: 8.42e+04 [312-2.14e+05] Bq/m3/h
    Accumulation rate: 17.5 [14.3-20.9] Bq/m3/h
----------------------
Useful information:
    Background [Rn] level: ~100 Bq/m3
    Maximum    [Rn] level: 800-1200 Bq/m3
    Effective ventilation time needed to flush Rn: 0-3 hours
    Maximum accumulation time with safe Rn levels: 10-15 hours
 
Please, keep the room ventilated for at least 10 minutes every 12 hours.
```

## Potential issues

Your CSV files should look like this:

<!---
![image](https://user-images.githubusercontent.com/53089531/191991075-5900ab53-ddfc-4321-a3cf-71188a065a8a.png)
--->

```
recorded;RADON_SHORT_TERM_AVG Bq/m3;TEMP °C;HUMIDITY %;PRESSURE hPa;CO2 ppm;VOC ppb
2022-09-22T10:10:33;;25.61;47.50;986.00;547.00;46.00
2022-09-22T10:15:33;;25.50;48.00;986.00;578.00;46.00
2022-09-22T10:20:33;;25.46;47.50;986.00;589.00;46.00
```

```
recorded;info
2022-09-22T10:10:00;Open
2022-09-22T18:00:00;Closed
2022-09-23T07:00:00;Open
2022-09-23T17:00:00;Closed
```

If you have a different model of radon-meter you might get other data, or data separated by comma ```,``` instead of a semicolon ```;```. If that is the case, you can change the ```delimiter``` in the ```textscan``` functions, or the data acquisition code below that.

## Short-term radon concentration data

Airthings detectors are [designed, made and, sold to collect long-term averages](https://help.airthings.com/en/articles/3119759-radon-how-is-radon-measured-how-does-an-airthings-device-measure-radon). That is why the detector reports 24h averages. Actually, [Airthings](https://www.airthings.com/) recommends tussing their products for a month to get accurate measurements.

However, some of us are very impatient and want to use our devices to test the mitigation actions we take in our houses and offices in a much shorter term (e.g. opening windows). Of course, this means that **we should forget about accuracy here**.

As these detectors calculate the Radon concentrations based on alpha particle counting, the **precision** of the measurements will be affected by counting statistics. Therefore, to estimate the uncertainty of the short-term measurements, I will assume that the perecentage of uncertainty will be represented by the formula ```100/N^0.5```, where ```N``` is the number of events (alpha decays) counted by the detector.

If we assume a conservative precision of [10% on the reported 24h measurements](https://help.airthings.com/en/articles/3727185-i-have-2-monitors-beside-each-other-and-they-show-different-radon-values-how-is-that-possible), "instant" 1h-data should yield about 50% uncertainties. Obviously, this uncertainty should decrease with higher Radon concentrations. In our initial tests, the scatter of the generated 1h-data seem to roughly reflect these 50% uncertainties for values around 500 Bq/m3. This implies that, *very rougly*, 1 event is detected per hour for each 100 Bq/m3 concentration. This value corresponds to an effective detection chamber of c. 3 cubic centimeters.

Scatter of the "1h data" in our initial tests and assumed uncertainty based on 1 count per 100 Bq/m3:

![image](https://user-images.githubusercontent.com/53089531/192155481-4bb32e3d-6e3a-43b5-9bd9-f633d1359bd3.png)

Following the same principle, 3h moving averages (light gray line in the output above) should have around 25% uncertainties. Uncertainties are calculated assuming  ``` N = [Rn]/100 * Δt```, being ```[Rn]``` the concentration in Bq/m3 and ```Δt``` the number of 1h data points considered.


