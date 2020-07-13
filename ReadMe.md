# Scripts

## NodeJS

* **Flatten JSON to CSV -** To be completed at a later time.
* **GSuite API Checker -** To be completed at a later time.

## PowerShell

* **Logic Apps Report Builder -** Loops through a CSV of Logic Apps to compile and output a recent activity and status report. The report will show the number of executions and their status.
    * **Parameters:**
        * **InputCsvPath -** File path to the input CSV that contains Logic Apps and associated details to loop over in order to build the report.
            * **CSV Schema -** `SubscriptionId,ResourceGroupName,LogicAppName,CustomerName,Direction`
            * **Default Value -** Current working directory's `inputs` directory named `Logic Apps List.csv`.
            * **Notes:**
                * Records that have a `SubscriptionId` that starts with a hash (`#`) will not be included in the report. This is most likely only used for development purposes.
        * **OutputCsvPath -** File path of where to output generated report.
            * **Default Value -** Current user's `Desktop` directory named `Logic Apps Report.csv`.
