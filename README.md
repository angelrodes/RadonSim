# RadonSim

A script written in the programming languages Matlab or Octave, utilizing data obtained from the Airthings Wave Air Quality Monitor and supplementary ventilation data input by the user, is employed to analyze the behavior of Radon gas within specific rooms. Through the utilization of this data, a ventilation pattern is proposed to **significantly reduce the risk of lung cancer**.

***This program is part of a work in progress. I will provide the reference for citation as soon as we publish it.***

Ángel Rodés, 2022 \
[www.angelrodes.com](https://www.angelrodes.com/)

## How to use

### Get Radon data

1. Follow the instructions from your Airthings Wave Plus monitor to setup the app in your phone. Create a new account if you don't have one.
2. After a few hours, you can log in and see your data online at [dashboard.airthings.com](https://dashboard.airthings.com/)
3. Download your data by clicking "Export to CSV":
![image](https://user-images.githubusercontent.com/53089531/191995763-0887d323-0b59-41bb-aa67-84ccd3095d4e.png)

### Create ventilation data

1. Use the template provided in the spreadsheet to record when you open or close the window in the room.
2. Using the same spreadsheet, create the csv air-circulation file. Note the format in the example given and make sure you are using the same time zone as in the radon data file, usually [UTC](https://en.wikipedia.org/wiki/Coordinated_Universal_Time).

### Fit the model and plot your data

1. Run the file ```RadonSim_v2.m``` in Matlab/Octave. 

> If you are using Linux and you have Octave installed, you can just run this in your terminal:

```bash
wget -O - https://raw.githubusercontent.com/angelrodes/RadonSim/main/RadonSim_v2.m | octave
```
The script will ask for the CSV files. Two files are given as example:

* Radon data file: ```2930129618-latest(20221121).csv```
* Air circulation file: ```Office217.csv```

## Output

![Screenshot at 2023-01-15 14-29-24](https://user-images.githubusercontent.com/53089531/212543552-89833092-6141-4697-a2be-4b1f34995234.png)

The raw Radon data is depicted vby a thick black line.

The ventilation pattern is drwan in blue at the top of the figure.

The script calculates and plots the 1h-recorded Radon data from the 24h-average data provided by the device. These data is used to calculate and plot (in light grey) the 3h average. See below for an explanation of the short term data.

The main purpose of the script is fitting a simple model to calculate the following paramenters:

* Maximum Radon concentration (Bq/m3) room is not ventilated for a long time.
* Maximum Radon concentration (Bq/m3) If the room is well ventilated.
* Ventilation rate (Bq/m3/h). Speed at with the Radon is eliminated when the air is circulating in the room.
* Accumulation rate (Bq/m3/h). Speed at with the Radon is accumulated in the room when the window is closed.

This model is fitted in the data using a converging Mote-Carlo method using a similar approach as in [Rodés *et al.* (2014)](https://doi.org/10.1016/j.quageo.2013.10.002).

Best fitting model is depicted in blue. 24h average corresponding to this model is depicted in magenta.

Best-fitting parameters and one-sigma ranges are diplayed in the text output, toguther with some useful (and very simplified) information: 

* How much time we need to ventilate to flush the Radon in the room.
* After ventilating and closing the window, how much time we can stay in the room with Radon concentrations [below 300 Bq/m3](https://www.who.int/data/gho/indicator-metadata-registry/imr-details/5618).

## Potential issues

Your csv files should look like this:

![image](https://user-images.githubusercontent.com/53089531/191991075-5900ab53-ddfc-4321-a3cf-71188a065a8a.png)

If you have a different model you might get other data, or data separated by comma (,) instead of semicolon (;). If that is the case, you can change the ```delimiter``` in the ```textscan``` functions, or the data a.

## Calculated short-term Radon data

Airthings detector are [designed, made and sold to collect long term averages](https://help.airthings.com/en/articles/3119759-radon-how-is-radon-measured-how-does-an-airthings-device-measure-radon). That is why the detector reports 24h averages. Actually, [Airthings](https://www.airthings.com/) recommends to use their productos for a month to get accurate measurements.

However, some of us are very impatient and want to use their porduts to test the mitigation actions we take in our houses and offices (e.g. opening windows) in a much shorter term. Of course, this means that **we should forget about accuracy here!**

As these detectors calculate the Radon concentrations based on alpha particle counting, the **precission** of the measurments will be affected by counting statistics. Therefore, to estimate the uncertainty of the short term measurements, I will assume that the uncertainty will be reresented by the formula ```100/N^0.5```, where ```N``` is the number of events (alpha decays) counted by the detector.

If we assume a conserviative precision of [10% on the reported 24h measurements](https://help.airthings.com/en/articles/3727185-i-have-2-monitors-beside-each-other-and-they-show-different-radon-values-how-is-that-possible), "instant" 1h-data should yield about 50% uncertainties. Obviusly, this uncertainty shuld decrease with higher Radon concentrations. In our initial tests, the scatter of the generated 1h-data seem to rougly reflect these 50% uncertainties for values around 500 Bq/m3. This implies that, *very rougly*, 1 event is detected per hour for each 100 Bq/m3 concentration. This value correspond to an effective detection chamber of c. 3 cubic centimeters.

Scatter of the "1h data" in our initial tests and assumed uncertainty based on 1 count per 100 Bq/m3:

![image](https://user-images.githubusercontent.com/53089531/192155481-4bb32e3d-6e3a-43b5-9bd9-f633d1359bd3.png)

Following the same principle, 3h moving averages (solid green line in the plot below) should have around 25% uncertainties. Uncertainties are calculated assuming  ``` N = [Rn]/100 * Δt```, being ```[Rn]``` the concentration in Bq/m3 and ```Δt``` the number of 1h data points considered.

<!---
![image](https://user-images.githubusercontent.com/53089531/192155570-eee26339-dc1d-4f6a-90d3-a38e16f0e873.png)

**6h moving average is plotted to test short-term "experiments".** This value is calculated as an average of 7 1h-data-points: from 3 hours before to 3 hours after. Therefore, **this is a moving average, not the average of the previous 6 hours.** Consequently, first and last 6h averages are the average of the first and last 4 data points respectively.
--->
