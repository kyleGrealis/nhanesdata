## R CMD check results

0 errors | 0 warnings | 1 note

The single NOTE is "checking for future file timestamps ... unable to verify current time",
which is a network/firewall issue on the local machine and not related to the package itself.

## Test environments

+ local: Windows 11 x64 (build 26200), R 4.5.2
+ GitHub Actions: ubuntu-latest, R release
+ win-builder: R devel

## Notes

The package provides access to pre-processed NHANES data hosted on
Cloudflare R2 cloud storage. All datasets are publicly accessible
and require no authentication.
