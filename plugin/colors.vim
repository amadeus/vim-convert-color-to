let s:hex_shorthand_regex = '#\([a-fA-F0-9]\)\([a-fA-F0-9]\)\([a-fA-F0-9]\)\([a-fA-F0-9]\)\=\>'
let s:hex_regex = '#\([a-fA-F0-9]\{2}\)\([a-fA-F0-9]\{2}\)\([a-fA-F0-9]\{2}\)\([a-fA-F0-9]\{2}\)\=\>'
let s:rgb_regex = 'rgba\=(\(\s*[0-9.]\+[ ,]*\)\(\s*[0-9.]\+[ ,]*\)\(\s*[0-9.]\+[ ,]*\)\(\s*[0-9.]\+[ ,]*\)\=)'
let s:hsl_regex = 'hsla\=(\(\s*[0-9.]\+\%(deg\|rad\|turn\|grad\)\=[ ,]\+\)\([0-9]\+%[ ,]\+\)\([0-9]\+%[ ,/]*\)\([0-9.]\+%\= *\)\=)'
let s:normalize_hex_digits = {idx, val -> str2nr('0x'.val, 16) / 255.0}
let s:normalize_hex_shorthand_digits = {idx, val -> str2nr('0x'.val.val, 16) / 255.0}
let s:pi = 3.14159265359

" Native viml min/max functions cannot accept floats...
function! s:Min(vals) abort
	let l:min = 2.0
	for l:item in a:vals
		if l:item < l:min
			let l:min = l:item
		endif
	endfor
	return l:min
endfunction

function! s:Max(vals) abort
	let l:max = -1.0
	for l:item in a:vals
		if l:item > l:max
			let l:max = l:item
		endif
	endfor
	return l:max
endfunction

function! s:NormalizeDigits(idx, val) abort
	if a:idx <= 2
		" If the value has is an integer - convert to float percentage of 0-255
		return matchstr(a:val, '\.') == '.' ? str2float(a:val) : str2nr(a:val) / 255.0
	endif
	return str2float(a:val)
endfunction

function! s:NormalizeHSLDigits(idx, val) abort
	if a:val =~# '%'
		return str2nr(a:val) / 100.0
	endif
	if a:val =~# 'rad'
		let l:rad = str2float(a:val)
		let l:degree = float2nr(round(l:rad * 180.0 / s:pi))
		" Ensure we never have values over 360
		return (l:degree % 360) / 360.0
	endif
	if a:val =~# 'grad'
		let l:grad = float2nr(round(str2float(a:val)))
		" Ensure we never have values over 400
		return (l:grad % 400) / 400.0
	endif
	if a:val =~# '\.'
		return str2float(a:val)
	endif
	return str2nr(a:val) / 360.0
endfunction

" Converting to and from hsl is a bit complicated, and destructive
" https://stackoverflow.com/questions/2353211/hsl-to-rgb-color-conversion
function! s:HueToRGB(p, q, t) abort
	let l:p = a:p
	let l:q = a:q
	let l:t = a:t
	if l:t < 0
		let l:t = l:t + 1.0
	endif
	if l:t > 1
		let l:t = l:t - 1.0
	endif

	if l:t < 1.0 / 6.0
		return l:p + (l:q - l:p) * 6.0 * l:t
	endif
	if l:t < 1.0 / 2.0
		return l:q
	endif
	if l:t < 2.0 / 3.0
		return l:p + (l:q - l:p) * (2.0 / 3.0 - l:t) * 6.0
	endif
	return l:p
endfunction

function! s:HSLToRGB(vals) abort
	let l:red = 0.0
	let l:green = 0.0
	let l:blue = 0.0
	let l:hue = a:vals[0]
	let l:saturation = a:vals[1]
	let l:lightness = a:vals[2]
	if l:saturation == 0
		let l:red = l:lightness
		let l:green = l:lightness
		let l:blue = l:lightness
	else
		let l:q = l:lightness < 0.5 ? l:lightness * (1.0 + l:saturation) : l:lightness + l:saturation - l:lightness * l:saturation
		let l:p = 2.0 * l:lightness - l:q
		let l:_hue = l:hue + 1.0 / 3.0
		let l:red = s:HueToRGB(l:p, l:q, l:_hue)
		let l:green = s:HueToRGB(l:p, l:q, l:hue)
		let l:_hue = l:hue - 1.0 / 3.0
		let l:blue = s:HueToRGB(l:p, l:q, l:_hue)
	endif

	" Append alpha if it exists
	let l:colors = [l:red, l:green, l:blue]
	if len(a:vals) == 4
		call add(l:colors, a:vals[3])
	endif
	return l:colors
endfunction

" Attempt to parse and normalize the string for a specific color
function! s:ParseString(str, matcher, normalize) abort
	let l:list = matchlist(a:str, a:matcher)
	let l:match = v:null
	if len(l:list) > 0
		let l:match = l:list[0]
	endif

	let l:data = map(
		\ filter(list, {idx, val -> idx == 0 || val == '' ? 0 : 1}),
		\ a:normalize
	\ )

	if len(l:data) == 0
		return v:null
	endif

	return {
		\ 'match': l:match,
		\ 'match_pos': match(a:str, a:matcher),
		\ 'normalized_data': l:data,
		\ 'color_string': ''
	\ }
endfunction

" Attempt to figure out string type and normalize the data from it
function! s:NormalizeString(str) abort
	" Is it a valid shorthand hex[a]?
	let l:match = s:ParseString(a:str, s:hex_shorthand_regex, s:normalize_hex_shorthand_digits)
	if type(l:match) == type({})
		let l:match['type'] = 'hex'
		return l:match
	endif

	" Is it a valid hex[a]?
	let l:match = s:ParseString(a:str, s:hex_regex, s:normalize_hex_digits)
	if type(l:match) == type({})
		let l:match['type'] = 'hex'
		return l:match
	endif

	" Is it a valid rgb[a]?
	let l:match = s:ParseString(a:str, s:rgb_regex, function('s:NormalizeDigits'))
	if type(l:match) == type({})
		let l:match['type'] = 'rgb'
		return l:match
	endif

	" Is it a valid hsl[a]?
	let l:match = s:ParseString(a:str, s:hsl_regex, function('s:NormalizeHSLDigits'))
	if type(l:match) == type({})
		let l:match['type'] = 'hsl'
		" Convert hsla decimals into rgba decimals
		let l:match['normalized_data'] = s:HSLToRGB(l:match['normalized_data'])
		return l:match
	endif

	return v:null
endfunction

function! s:FormatRGBString(vals) abort
	return 'rgb'.(len(a:vals) == 4 ? "a" : "").'('.join(map(a:vals, {idx, val -> val == 0 ? 0 : string(val)}), ', ').')'
endfunction

function! s:FormatDefaultRGBString(vals) abort
	let l:default = 'int'
	if exists('b:convert_color_default_rgb')
		let l:default = b:convert_color_default_rgb
	elseif exists('g:convert_color_default_rgb')
		let l:default = g:convert_color_default_rgb
	endif

	if l:default == 'float'
		return s:FormatRGBFloatString(a:vals)
	else
		return s:FormatRGBIntString(a:vals)
	endif
endfunction

function! s:FormatRGBIntString(vals) abort
	return s:FormatRGBString(map(a:vals, {idx, val -> idx == 3 ? val : float2nr(round(val * 255))}))
endfunction

function! s:FormatRGBFloatString(vals) abort
	return s:FormatRGBString(a:vals)
endfunction

function! s:FormatRGBAString(vals) abort
	let l:vals = a:vals
	if len(l:vals) == 3
		call add(l:vals, 1)
	endif
	let l:Formatter = get(s:Formatters, 'rgb')
	return l:Formatter(l:vals)
endfunction

function! s:FormatHEXString(vals) abort
	return '#'.join(map(a:vals, {idx, val -> printf('%02x', float2nr(round(val * 255)))}), '')
endfunction

function! s:FormatHEXAString(vals) abort
	let l:vals = a:vals
	if len(l:vals) == 3
		call add(l:vals, 1)
	endif
	let l:Formatter = get(s:Formatters, 'hex')
	return l:Formatter(l:vals)
endfunction

function! s:FormatHSLString(vals) abort
	let l:colors = a:vals[0:2]
	let l:min = s:Min(colors)
	let l:max = s:Max(colors)
	let l:lightness = (l:min + l:max) / 2
	let l:saturation = 0
	let l:hue = 0

	if l:min != l:max
		let l:diff = l:max - l:min
		let [l:red, l:green, l:blue] = l:colors
		if l:lightness > 0.5
			let l:saturation = l:diff / (2 - l:max - l:min)
		else
			let l:saturation = l:diff / (l:max + l:min)
		endif
		if l:max == l:red
			let l:hue = (l:green - l:blue) / l:diff + (l:green < l:blue ? 6.0 : 0.0)
		elseif l:max == l:green
			let l:hue = (l:blue - l:red) / l:diff + 2
		elseif l:max == l:blue
			let l:hue = (l:red - l:green) / l:diff + 4
		endif
		let l:hue = l:hue / 6
	endif
	let l:has_alpha = len(a:vals) == 4

	let l:formatted_vars = [float2nr(round(l:hue * 360)), float2nr(round(l:saturation * 100)), float2nr(round(l:lightness * 100))]
	if l:has_alpha == 1
		call add(l:formatted_vars, a:vals[3])
	endif

	return 'hsl'.(l:has_alpha == 1 ? 'a' : '').'('.join(map(l:formatted_vars, {idx, val -> idx == 0 || idx == 3 ? string(val): printf('%d%%', val)}), ', ').')'
endfunction

function! s:FormatHSLAString(vals) abort
	let l:vals = a:vals
	if len(l:vals) == 3
		call add(l:vals, 1)
	endif
	let l:Formatter = get(s:Formatters, 'hsl')
	return l:Formatter(l:vals)
endfunction

let s:Formatters = {
	\ 'hex': function('s:FormatHEXString'),
	\ 'hexa': function('s:FormatHEXAString'),
	\ 'rgb': function('s:FormatDefaultRGBString'),
	\ 'rgb_int': function('s:FormatRGBIntString'),
	\ 'rgb_float': function('s:FormatRGBFloatString'),
	\ 'rgba': function('s:FormatRGBAString'),
	\ 'hsl': function('s:FormatHSLString'),
	\ 'hsla': function('s:FormatHSLAString')
\ }

function! s:ConvertColor(str, format) abort
	let l:data = s:NormalizeString(a:str)
	if type(l:data) == type(v:null)
		echom 'No valid color to convert'
		return v:null
	endif

	" If the format is not specified, all -> hex, hex -> rgb
	" The reason hsl isn't in here is because it can be destructive,
	" it's also not commonly used
	let l:format = a:format
	let l:Formatter = get(s:Formatters, l:format, v:null)
	if l:Formatter == v:null
		if l:data['type'] != 'hex'
			let l:format = 'hex'
			let l:Formatter = get(s:Formatters, 'hex')
		else
			let l:format = 'rgb'
			let l:Formatter = get(s:Formatters, 'rgb')
		endif
	endif

	let l:data['color_string'] = l:Formatter(l:data['normalized_data'])
	return l:data
endfunction

function! s:GetContentSelection(line_start, line_end) abort
	let l:lines = getline(a:line_start, a:line_end)
	if len(l:lines) == 0
		return v:null
	endif

	let l:is_multiline = len(l:lines) > 1
	if is_multiline
		let l:column_start = getpos("'<")[2]
		let l:column_end = getpos("'>")[2]
		let l:lines[-1] = l:lines[-1][: l:column_end - (&selection == 'inclusive' ? 1 : 2)]
		let l:lines[0] = l:lines[0][l:column_start - 1:]
	else
		let l:column_start = 0
		let l:column_end = len(l:lines[0])
	endif

	return {
		\ 'selected_text': join(l:lines, "\n"),
		\ 'range': l:is_multiline ? "'<,'>" : a:line_start.','.a:line_end,
		\ 'row': a:line_start,
		\ 'column': l:column_start
	\}
endfunction

function! ConvertColorTo(...) range abort
	if !&modifiable
		echomsg 'Error: Cannot modify current file.'
		return
	endif

	let l:type = len(a:000) > 0 ? a:000['0'] : v:null

	" If calling with 2 args, then just return the new color and log the
	" conversion since we are assuming the user just wants display output or
	" evaluate to the expression register
	if len(a:000) == 2
		let l:converted_data = s:ConvertColor(a:000['1'], l:type)
		if type(l:converted_data) == type(v:null)
			" No error message because it should've already been displayed earlier
			return
		endif
		echom 'Converted '.l:converted_data['match'].' -> '.l:converted_data['color_string']
		return l:converted_data['color_string']
	endif

	let l:selection_data = s:GetContentSelection(a:firstline, a:lastline)
	let l:converted_data = s:ConvertColor(l:selection_data.selected_text, l:type)
	if type(l:converted_data) == type(v:null)
		" No error message because it should've already been displayed earlier
		return
	endif
	execute "silent ".l:selection_data.range."s/".escape(l:converted_data['match'], '/')."/".l:converted_data['color_string']
	" Move cursor to the start of the chage... not quite working on multiline
	" selects tho
	call setpos('.', [0, l:selection_data.row, l:selection_data.column + l:converted_data['match_pos'], 0])
	echom 'Converted '.l:converted_data['match'].' -> '.l:converted_data['color_string']
endfunction

command! -nargs=* -range ConvertColorTo <line1>,<line2>call ConvertColorTo(<f-args>)
