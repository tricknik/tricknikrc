" -*- vim -*-
"
" This is the (P)HP(D)ocumentor (S)kript for VIM (PDocS for short)
"
" Copyright (c) 2002, 2003 by Karl Heinz Marbaise <khmarbaise@gmx.de>
" 
" This is a script for simplifying documentation of PHP code
" using PHPDocumentor (www.phpdoc.org) Doc-Blocks.
" Most of the time you will copy/paste the commets from one place to
" another but with this script you will be able to generate PHPDoc
" while you are typing source-code.
"
" Release:      0.26a
"
" Tested:       VIM 6.1, VIM 7.0, VIM 7.1
" 
" Version:      $Id: phpdoc.vim,v 1.8 2003/01/05 14:59:41 kama Exp $
" 
" Author:       Karl Heinz Marbaise <khmarbaise@gmx.de>
"               Markus Fischer <markus@fischer.name>
"                   (For Changes, see below)
"
" Installation: Just copy it to your plugin directory
"               Change Authors-Name and e-mail adress and may be the text
"               which will be inserted.
"               
" Description:  It supports you in writing PHPDoc-Style Block-Comments
"               while writing PHP-Code. Using this script it is no
"               more needed to copy and paste the PHPDoc-Style Block-Commets
"               over and over you just type e.g. "class Test {" and you will 
"               get an filled out PHPDoc-Style Block comments above the class.
"
" Feedback:     If you have improvements, corrections, critism etc.
"               I'm apreciated to here from you about your comments etc.
"               just drop an e-mail to me.
"
" Todo:     -   I would like to have the text which will be inserted for
"               functions/classes/vars etc. in an external file which can be 
"               changed during runtime instead of hacking this script!
"           -   Improve doc.
"
" Plans:    -   Create a Unit-Testing script based on just the Class-Name
"               (skeleton)
"
" This Skript is based on the following styleguide conventions.
"
"   Variables: (prefix in lowercase)
"       $aTest  Array
"       $bTest  Boolean
"       $dTest  double
"       $sTest  string
"       $iTest  integer
"       $oTest  object
"       $rTest  ressource
"
"   methods:
"        if starting with "is..." then no prefix is used but return boolean
"        (isEqual, isSet etc.)
"
" Changes: (by Markus Fischer)
"               - Added recogniation of ressource type
"               - Concentrate on PHP5, removed access detectors
"               - Properly work with underscores in front of variables and
"                 functions
"               - Evaluate function parameters for their types, not just
"                 properties and function return values
"               - No @return on constructors
"               - Support phpdoc for interfaces, abstract and final classes
"               - Position cursor where it was after inserting phpdoc. This
"                 allows to continue writing code without interruption.
"               - Optionally add parameter name after @param type
"               - Added phpdoc_BackLineEval, which means class, functions and
"                 properties can span multiple lines and still generate a
"                 proper phpdoc
"               - Let the user decide what exactly to generate
"                 (g:phpdoc_generate)
"               - Align parameter types and names with spaces
"               - Use advanced phpdoc tag templating Dictionary
"               - Option to add spaced lines between TODOs (class_short_sace,
"                 class_long_space, func_short_pace, prop_todo_space)
"               - Option to add 'Optional, defaults to xx.' documentation to
"                 optional paramaters (func_params_optional)
"               - Option to add 'Defaults to xx.' documentation to
"                 properties (prop_var_default)

" No way this works < vim 7.0
if version < 700
    finish
endif

" User Configuration:
" Override any values in your user vimrc
if !exists('g:phpdoc_BackLinesEval')
let g:phpdoc_BackLinesEval      = 3     " if we don't find a class/interface/function
                                        " declaration, how many lines go back
                                        " to find it. May impact performance,
                                        " yet untested what kind of impact.
                                        " 0 - disables the feature
endif
if !exists('g:phpdoc_DefineAutoCommands')
let g:phpdoc_DefineAutoCommands = 1     " default 1, define autocommands.
endif

" Support of user specific phpdoc tags. Example dictionary:
"  let g:phpdoc_tags = {
"              \   'class' : {
"              \       'author'        :   'Markus Fischer <markus@fischer.name>',
"              \       'since'         :   strftime('%Y-%m-%d'),
"              \       'copyright'     :   '(c) ' . strftime('%Y') . ' Company',
"              \       'version'       :   '$Id',
"              \       'package'       :   'Mfn',
"              \   },
"              \   'function' : {
"              \       'author'        :   'Markus Fischer <markus@fischer.name>',
"              \       'since'         :   strftime('%Y-%m-%d'),
"              \   },
"              \   'property' : {
"              \       'since'         :   strftime('%Y-%m-%d'),
"              \       
"              \   }
"              \}
" Only 'class', 'function' and 'property' are recognized, their tags and
" content is totally up to you.
if !exists('g:phpdoc_tags')
    let g:phpdoc_tags = {}
endif

" List of recognized elements we generate witha phpdoc. The default is to
" generate everything.
if !exists('g:phpdoc_generate')
let g:phpdoc_generate = [
            \ 'class',
            \ 'class_short',
            \ 'class_short_space',
            \ 'class_long',
            \ 'class_long_space',
            \
            \ 'func',
            \ 'func_short',
            \ 'func_short_space',
            \ 'func_params',
            \ 'func_params_name',
            \ 'func_params_optional',
            \ 'func_return',
            \
            \ 'prop',
            \ 'prop_todo',
            \ 'prop_todo_space',
            \ 'prop_var',
            \ 'prop_var_default',
            \ ]
endif

" Enable phpdoc. Automatically inject docs when coding.
if g:phpdoc_DefineAutoCommands
    augroup phpdoc
        autocmd BufEnter *.php inoremap { {<Esc>:call PHPDOC_DecideClassOrFunc()<CR>a
        autocmd BufEnter *.php inoremap ; ;<Esc>:call PHPDOC_ClassVar()<CR>a
        autocmd BufLeave *.php iunmap {
        autocmd BufLeave *.php iunmap ;
    augroup END
    " Keep your braces balanced!}}}
endif " g:phpdoc_DefineAutoCommands

" Utility function to check whether the user wants to generate a specific
" phpdoc element
function! PHPDOC_generate(what)
    let what = '^' . a:what . '$'
    if match(g:phpdoc_generate, what) > -1
        return 1
    else
        return 0
    endif
endfunction

" Uses the known patterns how to identify classes, interfaces and functions
" and determines which phpdoc to generate. Supports declarations which span
" multiple lines.
function! PHPDOC_DecideClassOrFunc()
    let patClass = '^\s*\(\(\(abstract\|final\)\s*\)*class\|interface\)'
    let patFunc = '^\s*\(\(abstract\|public\|protected\|private\|static\|final\)\s\+\)*function\s\+[A-za-z]'
    let [line, back, patIndex] = PHPDOC_GetBackLines(patClass, patFunc)
    if PHPDOC_CommentBeforeLine(back)
        return
    endif
    if patIndex == 0
        call PHPDOC_ClassHeader(line, back)
    elseif patIndex == 1
        if PHPDOC_generate('func')
            call PHPDOC_FuncHeader(line, back)
        endif
    else
        return
    endif
endfunction

" Go back a number of lines and try matching the pattern until found. That is,
" we return the whole lines as a single string as soon as the pattern
" matches. This is important so we don't jump into another defintion.
function! PHPDOC_GetBackLines(...)
    if a:0 == 0
        throw 'At least one pattern is required'
    endif
    let lineNo = 0
    let line = ''
    let back = 1
    if exists('g:phpdoc_BackLinesEval') && g:phpdoc_BackLinesEval > 0
        let back = g:phpdoc_BackLinesEval
    endif
    while lineNo < back
        let line = getline(line('.') - lineNo) . line
        " remove line breaks
        let line = substitute(line, '\r?\n', '', '')
        let patIndex = 0
        while patIndex < a:0
            if line =~ a:000[patIndex]
                return [ line, lineNo, patIndex]
            endif
            let patIndex = patIndex + 1
        endwhile
        let lineNo = lineNo + 1
    endwhile
    return ['', -1, -1]
endfunction

" Get the Type of an variable/function/method
" based on the prefixes defines in styleguide
" If no prefix matches we use 'mixed' as type.
function! PHPDOC_GetPHPDocType(prefix)
    let type = 'mixed'
    if a:prefix == 'a'
        let type = 'array'
    endif
    if a:prefix == 'b'
        let type = 'bool'
    endif
    if a:prefix == 'd'
        let type = 'double'
    endif
    if a:prefix == 'i'
        let type = 'int'
    endif
    if a:prefix == 's'
        let type = 'string'
    endif
    if a:prefix == 'o'
        let type = 'object'
    endif
    if a:prefix == 'r'
        let type = 'resource'
    endif
    return type
endfunction

" Check if a function starts with "set" or "is", 
" cause it is most often used for "get"/"set" operation
" of classes and "is" is used for checking if set...
" like "isEnabled()" etc. for boolean functions.
function! PHPDOC_GetReturnOfPHPFunction(line,index)
    let returntype = 'TODO'
    " Does the function name start with "set..."?
    if match(a:line, '^set', a:index) > -1
        return returntype
    " Does the function name start with "is..."?
    elseif match(a:line, '^is', a:index) > -1
        " Such kind of functions are like isEnabled () so the return
        " type is 'boolean'.
        let returntype = 'boolean'
    else    
        let prefix = matchstr(a:line, '[A-Za-z]', a:index) 
        " Get return type of function base on Prefix...
        " TODO: disabled, make future config option for it. Reason for
        " disabling: hardly useful, seldom method want to be prefix with
        " return value, hinders readability
        " let returntype = GetPHPDocType(prefix) 
    endif
    return returntype
endfunction
function PHPDOC_CommentBeforeLine(...)
    let goLinesBack = 1
    
    if a:0 == 1
        let goLinesBack = goLinesBack + a:1
    endif
    if getline(line(".") - goLinesBack) =~ '^\s*\*/\s*$'
        return 1
    else
        return 0
    endif
endfunction

" This function is called every time you type "{"
" this is usualy done if you are declaring a class or a function
function! PHPDOC_ClassHeader(line, back)
    let line = a:line
    let back = a:back

    if match(line, '\s*interface') > -1
        if ! PHPDOC_generate('interface')
            return
        endif
    else
        if ! PHPDOC_generate('class')
            return
        endif
    endif

    " Get the prefix of the line to indent the
    " auto inserted text the same as the rest...
    let indent = matchstr(line, '^\s*')
    let @z = indent . "/**\n"
    if PHPDOC_generate('class_short')
        let @z=@z . indent . " * TODO: short description.\n"
        if PHPDOC_generate('class_short_space')
            let @z=@z . indent . " * \n"
        endif
    endif
    if PHPDOC_generate('class_long')
        let @z=@z . indent . " * TODO: long description.\n"
        if PHPDOC_generate('class_long_space')
            let @z=@z . indent . " * \n"
        endif
    endif

    let @z=@z . PHPDOC_UserTags('class', indent)

    let @z=@z . indent . " */\n"

    " store current cursor position ...
    normal! ma
    " respect how many lines we've to go back
    let i = 0
    while i < back
        normal! k
        let i = i + 1
    endwhile
    put! z
    " ... and restore it after insertion
    normal! `a
endfunction

" Insert a Header every time you begin a new function
function! PHPDOC_FuncHeader(line, back)
    let line = a:line
    let back = a:back

    " Get the prefix of the line to indent the
    " auto inserted text the same as the rest...
    let indent = matchstr(line, '^\s*')
    let @z = ''
    " default empty type...
    let returntype = ''

    let index = matchend(line, 'function\s\+_\?')
    let returntype = PHPDOC_GetReturnOfPHPFunction(line,index)

    " Constructors don't have returntypes, so don't pre-fill them in such a
    " case
    let showReturnType = 1
    if line =~ '__construct'
        let showReturnType = 0
    endif
    
    let @z=@z . indent . "/**\n"
    if PHPDOC_generate('func_short')
        let @z=@z . indent . " * TODO: short description.\n"
        if PHPDOC_generate('func_short_space')
            let @z=@z . indent . " * \n"
        endif
    endif
    if PHPDOC_generate('func_params')
        " evaluate each parameter for it's prefix for type decision
        if line =~ '(.*)'

            " remove leading and trailing characters from the braces
            let paramString = substitute(line, '.*(\(.*\)).*', '\1', '')

            " break up string into array
            let paramList = split(paramString, ',')

            " First pass: Determine longest type and name for alignment
            let longest_paramName = 0
            let longest_paramType = 0
            for parameter in paramList
                let index = matchend(parameter, '\$')
                " If we've a typehint, use that as type instead looking at the prefix
                let typehint = matchlist(parameter, '\([A-Za-z0-9_:]\+\)\s\+\$')
                if exists('typehint[1]')
                    if len(typehint[1]) > longest_paramType
                        let longest_paramType = len(typehint[1])
                    endif
                else
                    let prefix = matchstr(parameter, '[A-Za-z]', index)
                    let paramType = PHPDOC_GetPHPDocType(prefix)
                    if len(paramType) > longest_paramType
                        let longest_paramType = len(paramType)
                    endif
                endif
                let paramName = matchstr(parameter, '[A-Za-z0-9_]\+', index)
                if len(paramName) > longest_paramName
                    let longest_paramName = len(paramName)
                endif
            endfor
            " Add spaces for alignment
            let longest_paramType = longest_paramType + 2 " just two spaces for clear separation
            let longest_paramName = longest_paramName + 2 " one for the $ and one for the space after

            " Second pass: actually build the phpdoc strings
            for parameter in paramList
                " If we've a typehint, use that as type instead looking at the prefix
                let typehint = matchlist(parameter, '\([A-Za-z0-9:_]\+\)\s\+\$')
                if exists('typehint[1]')
                    let @z=@z . indent . " * @param  " . typehint[1]
                    let @z=@z . repeat(' ', longest_paramType - len(typehint[1]))
                else
                    let index = matchend(parameter, '\$')
                    let prefix = matchstr(parameter, '[A-Za-z]', index)
                    let paramType = PHPDOC_GetPHPDocType(prefix)
                    let @z=@z . indent . " * @param  " . paramType
                    let @z=@z . repeat(' ', longest_paramType - len(paramType))
                endif
                if PHPDOC_generate('func_params_name')
                    let paramName = matchstr(parameter, '\$[A-Za-z0-9_]\+')
                    let @z=@z . paramName
                    " now add alignment
                    let @z=@z . repeat(" ", longest_paramName - len(paramName))
                endif
                if PHPDOC_generate('func_params_optional')
                    let paramOptional = matchlist(parameter, '\$[A-Za-z0-9_]\+\s*=\s*\(.*\)')
                    if exists('paramOptional[1]')
                        let @z=@z . 'Optional, defaults to ' . paramOptional[1] . '. '
                    endif
                endif
                let @z=@z . "\n"
            endfor
        endif
    endif

    if PHPDOC_generate('func_return') && showReturnType
        let @z=@z . indent . " * @return " . returntype . "\n"
    endif

    let @z=@z . PHPDOC_UserTags('function', indent)

    let @z=@z . indent . " */\n"
    " store current cursor position ...
    normal! ma
    " respect how many lines we've to go back
    let i = 0
    while i < back
        normal! k
        let i = i + 1
    endwhile
    put! z
    " ... and restore it after insertion
    normal! `a
endfunction

" Create class variable documentation.
function! PHPDOC_ClassVar()
    if !PHPDOC_generate('prop')
        return
    endif

    let pattern = '^\s*\(\(public\|protected\|private\|static\|var\)\s\+\)\+\$'

    let [line, back, patIndex] = PHPDOC_GetBackLines(pattern)
    if PHPDOC_CommentBeforeLine(back)
        return
    endif
    if patIndex != 0
        return
    endif

    " Get the prefix of the line to indent the
    " auto inserted text the same as the rest...
    let indent = matchstr(line, '^\s*')
    " check if the first character of the name "_"
    " and get the prefix of the variable name...to get the type..
    " Determine the first alpha-character of the variable so we can determine
    " the type of it.
    let index = matchend(line, '\$_\?')
    let prefix = matchstr(line, '[A-Za-z]', index) 

    let type = PHPDOC_GetPHPDocType(prefix)

    let @z= indent . "/**\n"
    if PHPDOC_generate('prop_todo')
        let @z=@z . indent . " * TODO: description.\n"
        if PHPDOC_generate('prop_todo_space')
            let @z=@z . indent . " * \n"
        endif
    endif
    if PHPDOC_generate('prop_var')
        let @z=@z . indent . " * @var " . type
    endif
    if PHPDOC_generate('prop_var_default')
        let paramDefault = matchlist(line, '\$[A-Za-z0-9_]\+\s*=\s*\(.*\);')
        if exists('paramDefault[1]')
            let @z=@z . '  Defaults to ' . paramDefault[1] . '. '
        endif
    endif
    let @z=@z . "\n"


    let @z=@z . PHPDOC_UserTags('property', indent)

    let @z=@z . indent . " */\n"
    " store current cursor position ...
    normal! ma
    " respect how many lines we've to go back
    let i = 0
    while i < back
        normal! k
        let i = i + 1
    endwhile
    put! z
    " ... and restore it after insertion
    normal! `a
endfunction

function! PHPDOC_UserTags(which, indent)
    let comments = ''
    if exists("g:phpdoc_tags['" . a:which . "']")
        let longest_key = 0
        for [key, value] in items(g:phpdoc_tags[a:which])
            if len(key) > longest_key
                let longest_key = len(key)
            endif
        endfor
        let longest_key = longest_key + 1
        for [key, value] in items(g:phpdoc_tags[a:which])
            let comments = comments . a:indent . " * @" . key . repeat(' ', longest_key - len(key)) . value . "\n"
        endfor
    endif
    return comments
endfunction
