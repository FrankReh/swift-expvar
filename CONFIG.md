# expvar.json

The configuration file used by expvar at startup. It is in JSON format.

## Location

The config file is searched for in the current working directory,
and then on macOS 10.12 and above platforms, in the user's home directory and
in an optional user's $HOME/upspin directory.

## Endpoints

The most important function of the config file is provide the filenames or directories to search
for IPC socket endpoints and the URLs for the TCP socket endpoints. If the configuration file is not
found, a default of $TMPDIR is used as the directory to search for IPC (unix domain) sockets.

## Window Geometry

Most of the configuration options have to deal with geometry of various windows
and elements within windows. Sometimes the font size and background color is spelled out too.

There is also a list of fieldnames that is used for defining the order of rows in the JSON window when expanding
a dictionary of the JSON tree. The JSON dictionary has no inherent sense of the order of the fields that came
across the wire.

These are development stopgap measures and will be moved into the source.
