# monitoring-plugins_check_fritzbox_docsis_parameters

Icinga/Nagios Check for DOCSIS Parameters on a Fritzbox Cable
Modem/Router.

Works with Fritzbox Cable Routers running EuroDOCSIS/DOCSIS versions
3.0 and 3.1. OK/WARNING/CRITICAL thresholds are currently hard coded
for 256QAM when operating DOCSIS 3.0 and 4096QAM when operating DOCSIS
3.1.

Perfdata is enabled, so given that you are using something like
PNP4Nagios, nice graphs will be drawn.

Optionally you can also dump the values to a CSV file.

Requires curl, html2text, bc, jq.

Rename config.dist.sh to config.sh and adjust configuration to suit
your needs.

Icinga config could look like this:

    define command{
        command_name check_docsis
        command_line /path/to/fritzbox.sh
    }

    define service {
        use                              generic-service
        host                             fritzbox-cable
        service_description              DOCSIS Parameters
        check_command                    check_docsis
    }

![Service Status Detail](docs/service-status.png)
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fnohn%2Fmonitoring-plugins_check_fritzbox_docsis_parameters.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2Fnohn%2Fmonitoring-plugins_check_fritzbox_docsis_parameters?ref=badge_shield)

![Availability Report](docs/availability-report.png)

![PNP4Nagios](docs/pnp4nagios.png)


## License
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fnohn%2Fmonitoring-plugins_check_fritzbox_docsis_parameters.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Fnohn%2Fmonitoring-plugins_check_fritzbox_docsis_parameters?ref=badge_large)