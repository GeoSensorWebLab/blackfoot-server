# Roadmap

This document details any future plans for this repository.

## Short Term Goals

These are some small things that can be added to improve the reliability and end user experience.

* Document how to set up the front-end site on the server
* Document configuration for transloading data from other data providers
* Document why things are being deployed directly to the system instead of using containerization
* Add support for HTTP/2, and benchmark performance difference
* Set up usage analysis so we can know what browsers and internet connections our users are using to connect to our services

## Long Term Goals

These tasks are larger and contribute more towards reducing the administration workload of managing these services.

* Switch to Chef for deployment
    * Even chef-zero would be useful for automatically deploying new changes to the server, and making it easy to set up new servers
* Deploy service monitoring
    * Some tools to monitor resource usage and any potential problems
* Deploy log collection
    * Send the application and system logs to another server for storage. Useful if this server becomes inaccessible or the data is lost, and the system administrator wants to find any clues in the logs.
* Use continuous deployment
    * Would allow changes to the transloader or front-end to be automatically deployed to the server if they pass certain conditions
