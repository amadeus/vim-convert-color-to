# ConvertColorTo

A simple and easy to use plugin that can convert various color strings to
different formats.  The goal was to create a simple and flexible API that
required no 3rd party dependencies.


### Quick Usage Reference

Given a line like this, with the cursor anywhere on it
```
background-color: rgb(241, 23, 102);
```

simply perform
```
:ConvertColorTo hex
```

and you'll get this:
```
background-color: #f11766;
```

You can also optionally make a visual selection of the color value, and
execute:
```
:'<,'>ConvertColorTo hex
```

Currently supported color formats are:

* `hex` -> `#001122`
* `hexa` -> `#00112233`
* `rgb` -> `rgb(0, 100, 200)`
* `rgb_int` -> `rgb(0, 100, 200)`
* `rgb_float` -> `rgb(0.1, 0.2, 0.3)`
* `rgba` -> `rgba(0, 100, 200, 0.3)`
* `hsl` -> `hsl(200, 20%, 10%)`
* `hsla` -> `hsla(100, 20%, 30%, 0.2)`

**Protip**: The plugin will always attempt to maintain a transparency value if
it exists in the original color (i.e. using type `rgb` on an `hsla`, will
actually convert it to `rgba` automatically).  However, if you are converting a
color that does not have a transparency, but specify a type with transparency,
the plugin will add a transparency of `1`.

Another **Protip**: You can use this plugin as a simple text formatter if you
apply the same type as the source color.


### Detailed Usage

There are a couple different ways to use the plugin.

Via the commandline:
```
:ConvertColorTo [type] [color_string]
:'<,'>ConvertColorTo [type]
```

Via the expression register:
```
=ConvertColorTo('[type]', '[color_string]')
:put =ConverColorTo('[type]', '[color_string]')
```

Or if you just want to see an echo of the color conversion:
```
:call ConvertColorTo('[type]', '[color_string]')
```

Both `type` and `color` are optional.

`type` is simply one of the above listed color formats. If no format is
specified then the plugin will attempt to convert the color to `hex`.  If it's
already `hex` then it will convert to `rgb` instead.  `type` must be specified
if you want to manually pass in a `color_string`.  If it becomes annoying I may
fix this later...

`color_string` is only needed if you don't have a text selection or an existing
color on the current line.  It's simply a color in any supported format to
convert.


### Configuration

You can specify a global or local config when using `rgb` or `rgba` to be
either `int` (default) or `float`

```
let g:convert_color_default_rgb = 'float'
let b:convert_color_default_rgb = 'int'
```


### Minor Philosophical Things

While this plugin does some basic validation of the color formats, it is by no
means a perfect and fully accurate parser.  There are cases where you could
potentially specify invalid strings and they might get converted or vice versa,
valid strings that don't get detected properly.  I did this mostly because I
just didn't care at the time, it should work 99% of the time for the common
cases.

With that said, if you do find a bug or what not, please let me know, maybe
it's easy to patch and we can improve the plugin.


### License

MIT License
