# AZLint / binaries

Because binaries take incredibly long time to compile from scratch and apply UPX to them (especially with multi-arch output),
we build them ahead of time in this subdirectory and just copy the results into the actual project's Dockerfile later.
This saves multiple minutes.
