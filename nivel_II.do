cls 
clear 
global health "C:\Users\51937\Documents\projects\Health"
global eess_ccpp "$health\eess_ccpp"

cd "$eess_ccpp"
*## Importación
import excel "$eess_ccpp\TB_EESS_CLEAR.xlsx", sheet("TB_EESS") firstrow
save "$eess_ccpp\TB_EESS_CLEAR", replace

*## Limpieza 
*considerar: 
/*
Primer nivel de atención:
Categoría I-1. Puesto de salud, posta de salud o consultorio con profesionales de salud no médicos.
Categoría I-2. Puesto de salud o posta de salud (con médico). Además de los consultorios médicos (con médicos con o sin especialidad).
Categoría I-3. Corresponde a los centros de salud, centros médicos, centros médicos especializados y policlínicos.
Categoría I-4. Agrupan los centros de salud y los centros médicos con camas de internamiento.
 

Segundo nivel de atención:
Categoría II-1. El conjunto de hospitales y clínicas de atención general.
Categoría II-2. Corresponde a los hospitales y clínicas con mayor especialización.
Categoría II-E. Agrupan a los hospitales y clínicas dedicados a la atención especializada.
 

Tercer nivel de atención:
Categoría III-1. Agrupan los hospitales y clínicas de atención general con mayores unidades productoras de servicios de salud.
Categoría III-E. Agrupan los hospitales y clínicas de atención general con mayores unidades productoras de servicios de salud y servicios en general.
Categoría III-2. Corresponden a los institutos especializados.
*/

browse if categoria == "SD"
drop if categoria == "SD"

codebook longitud //7,639 m

drop if categoria == "I-1" | categoria == "I-2" | categoria == "I-3" | categoria == "I-4" 
codebook longitud // 162 M
browse if longitud ==.


*##Imputación de coordenadas faltantes y limpieza 
preserve 
import excel using "$eess_ccpp\LAT_LONG", firstrow clear
save "$eess_ccpp\LAT_LONG", replace
restore 
merge 1:1 id_eess using "$eess_ccpp\LAT_LONG", keepusing(lat_long)

split lat_long, parse(",") generate(latitud)
ren latitud2 longitud1
destring latitud1, replace
destring longitud1, replace
replace latitud = latitud1 if latitud==.
replace longitud = longitud1 if longitud==.

codebook latitud
drop if latitud ==.
drop _merge 
drop latitud1 longitud1 lat_long

browse if strpos(diresa,"LIMA")
replace diresa = "LIMA" if strpos(diresa,"LIMA")

ren (diresa latitud longitud) (dep lat_ccss long_ccss)
save "$eess_ccpp\LAT_LONG", replace


*##base de centros poblados
cap ssc install shp2dta
cap ssc install spmap
shp2dta using CP_P.shp, ///
	database(ccpp) coordinates(coord_ccpp) genid(id) replace 

use ccpp.dta, replace
ren *, l
ren (xgd ygd) (long_ccpp lat_ccpp)
drop if dep==""
save ccpp.dta, replace


joinby dep using LAT_LONG

order nombre nomcp long_ccpp lat_ccpp long_ccss lat_ccss

*##Guardando unión
save ccpp_ccss.dta, replace

*##Distancia ccpp to ccss
ssc install geodist
geodist long_ccpp lat_ccpp long_ccss lat_ccss, gen(distance)
order distance

egen id_new = concat(id_eess codcp)

gen distancia = distance
gen dis = distance
order distancia distance dis 

*obteniendo las 3 ccss más cercanos a los ccpp
*Se puede mejorar obteniendo el promedio de los centros de salud más cercanos de los diferentes niveles   

recast long distance                     
bysort codcp: egen d1=min(distancia)
order d1
replace distancia=. if dis==d1 

bysort codcp: egen d2=min(distancia)
order d2
replace distancia=. if dis==d2 

bysort codcp: egen d3=min(distancia)
order d3
replace distancia=. if dis==d3 

egen d_mean = rowmean(d1 d2 d3)
order d_mean

*por categoría de ccss 
ta categoria

bysort codcp: egen d_II1 = min(distancia) if categoria == "II-1"
bysort codcp: egen d_II2 = min(distancia) if categoria == "II-2"
bysort codcp: egen d_IIE = min(distancia) if categoria == "II-E"
bysort codcp: egen d_III1 = min(distancia) if categoria == "III-1"
bysort codcp: egen d_III2 = min(distancia) if categoria == "III-2"
bysort codcp: egen d_IIIE = min(distancia) if categoria == "III-E"

order d_II*


snapshot save, label(ccpp)

collapse (mean) d_mean (min) distance d_II*, by(codcp categoria dep prov)

codebook codcp dep prov

save "Distancias_prov", replace
use Distancias_prov, clear

*## Shape provincias 
shp2dta using "$eess_ccpp\prov\PROVINCIAS_inei_geogpsperu_suyopomalia.shp", ///
	database(prov) coordinates(prov_coord) genid(id_prov) replace 
use prov, replace
ren *,l
ren nombprov prov 

merge 1:m prov using Distancias_prov
drop _merge 

order id_prov
sort id_prov

collapse (mean) d_mean distance, by(id_prov prov nombdep dep)

shp2dta using "$eess_ccpp\dep\DEPARTAMENTOS_inei_geogpsperu_suyopomalia.shp", ///
	database(dep) coordinates(dep_coord) genid(id_dep) gencentroids(dptocentro) replace
	
gen dist = distance 
format dist %9.2f

spmap dist using prov_coord, id(id_prov) fcolor(Blues2) clnumber(6) ocolor(Greys) polygon(data(dep_coord) ocolor(black)) title("Nivel provincial", size(*0.8)) legcount note("*/Se promedian las distancia de los CCPP a los EESS más cercanos entre los niveles II-1 y III-2." "*/Existen departamentos que no cuentan con EESS nivel III, lo que limita el estudio.", size(*0.80)) name(mapa1,replace)

collapse (mean) d_mean distance, by(nombdep dep)

preserve
use dep, clear 
ren *,l
ren nombdep dep
save dep, replace
restore

merge 1:1 dep using dep

format distance %9.2f

spmap distance using dep_coord, id(id_dep) fcolor(Blues2) clnumber(6) ocolor() title("Nivel departamental", size(*0.8)) legcount note("*/Se promedian las distancia de los CCPP a los EESS más cercanos entre los niveles II-1 y III-2." "*/Existen departamentos que no cuentan con EESS nivel III, lo que limita el estudio.", size(*0.80)) name(mapa2,replace)

graph combine mapa1 mapa2, title("Gráfico 1. Distancias promedio* (km): CCPP - EESS", size(*0.9)) name(combine1, replace) 
graph export "$eess_ccpp\combine1.png", replace
