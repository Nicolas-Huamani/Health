cls 
clear 
global health "C:\Users\51937\Documents\projects\Health"
global eess_ccpp "$health\eess_ccpp"

use "$eess_ccpp\TB_EESS_CLEAR", clear


drop if categoria == "SD"
keep if categoria == "III-1"|categoria == "III-2" | categoria == "III-E"

merge 1:1 id_eess using "$eess_ccpp\LAT_LONG", keepusing(lat_long)

drop if _merge ==2

*imputando missings desde la base LAT_LONG
split lat_long, parse(",") generate(latitud)
ren latitud2 longitud1
destring latitud1, replace
destring longitud1, replace
replace latitud = latitud1 if latitud==.
replace longitud = longitud1 if longitud==.

*borrando variables que no se necesitan
codebook latitud
drop if latitud ==.
drop _merge 
drop latitud1 longitud1 lat_long

*Uniformizando region LIMA
browse if strpos(diresa,"LIMA")
replace diresa = "LIMA" if strpos(diresa,"LIMA")

*renombrar para ordenar y emparejar 
ren (diresa latitud longitud) (dep_diresa lat_ccss long_ccss)
gen match = "i"

save "$eess_ccpp\LAT_LONG_II", replace

use "$eess_ccpp\ccpp", clear
gen match = "i"
save "$eess_ccpp\ccpp", replace

*joinby: emparejado

joinby match using LAT_LONG_II

order nombre nomcp long_ccpp lat_ccpp long_ccss lat_ccss

*Guardando unión
save "$eess_ccpp\ccpp_ccss_III.dta", replace

*Distancia ccpp to ccss
geodist long_ccpp lat_ccpp long_ccss lat_ccss, gen(distance)
order distance

*Creando variables de distancia 
gen distancia = distance
gen dis = distance
order distancia distance dis 

*Obteniendo distancias de ccpp a eess más cernaos
bysort codcp: egen d1 = min(distance)
bysort codcp categoria: egen d_cat = min(distance)
order d1 d_cat

*collapse por codcp categoria departamento al que pertenece el ccpp
collapse (mean) d1 d_cat, by(codcp categoria dep prov)  
*collapse por codcp dep 
collapse (mean) d1 d_cat, by(codcp dep)
*collapse por dep 
collapse (mean) d1 d_cat, by(dep)

*redondeando distancias a 2 decimales
format d1 %9.2f
format d_cat %9.2f 

*guardando base
save "$eess_ccpp\Distancias_dep", replace
use "$eess_ccpp\Distancias_dep", clear

*revisando el shpfile de departamentos obtenido del do en el ejercicio de provincias
use dep, clear
merge 1:1 dep using Distancias_dep

*spmap 
spmap d1 using dep_coord, id(id_dep) fcolor(Reds2) clnumber(5) ocolor() title("", size(*0.8)) legcount note("*/Se promedian las distancias de los CCPP al EESS nivel 3 más cercano", size(*0.85)) label(xcoord(x_dptocentro) ycoord(y_dptocentro) label(dep) color(black) size(*0.60)) name(mapa1_dep,replace)


spmap d_cat using dep_coord, id(id_dep) fcolor(Reds2) clnumber(5) ocolor() title("", size(*0.8)) legcount note("*/Se promedian las distancias de los CCPP a los EESS nivel 3 más cercanos por categorías.", size(*0.85)) label(xcoord(x_dptocentro) ycoord(y_dptocentro) label(dep) color(black) size(*0.60)) name(mapa2_dep,replace) 

graph combine mapa1_dep mapa2_dep, name(combine2, replace) title("Gráfico 2. Distancias promedio* (km): CCPP - EESS", size(*0.9)) subtitle("Nivel departamental")
graph export "$eess_ccpp\combine2.png", replace