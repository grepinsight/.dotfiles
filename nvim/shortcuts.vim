" Emoji shortcuts
" you type the :keyword: and type space
ab :shrug: 🤷
ab :bulb: 💡
ab :point_right: 👉
ab :white_check_mark: ✅
ab :link: 🔗

iabbrev obvi/ obviously
iabbrev pts/ points

iabbrev ma_s más
iabbrev fri_os fríos
iabbrev waht what
iabbrev que_ qué
iabbrev dejo_ dejó

iabbrev idk I don't know



try
  silent! call plug#load('vim-abolish')
catch
  finish
endtry

let g:abolish_save_file = expand('<sfile>')

if !exists(':Abolish')
  finish
endif

Abolish teh the
Abolish {p}y{o}bjext PyObject

" These are taken from tpope. Thanks!
Abolish anomol{y,ies}                         anomal{}
Abolish {,in}consistan{cy,cies,t,tly}         {}consisten{}
Abolish delimeter{,s}                         delimiter{}
Abolish {,non}existan{ce,t}                   {}existen{}
Abolish despara{te,tely,tion}                 despera{}
Abolish d{e,i}screp{e,a}nc{y,ies}             d{i}screp{a}nc{}
Abolish {,re}impliment{,s,ing,ed,ation}       {}implement{}
Abolish improvment{,s}                        improvement{}
Abolish inherant{,ly}                         inherent{}
Abolish lastest                               latest
Abolish persistan{ce,t,tly}                   persisten{}
Abolish seperat{e,es,ed,ing,ely,ion,ions,or}  separat{}
Abolish segument{,s,ed,ation}                 segment{}

Abolish pattners patterns
Abolish configuratoin configuration

abbreviate functoin function
abbreviate funtcion function
abbreviate functin function
abbreviate mvoe move
abbreviate scalble scalable
abbreviate scopped scoped
abbreviate lanauage language
Abolish respositories repositories

