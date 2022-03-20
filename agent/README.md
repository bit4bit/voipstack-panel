# vop-agent

Transforma eventos desde softswitch y aplicaciones acciones al mismo.


vop-agent -> core.js

vop-agent: servicio que conecta vop-panel y translator.js, provee interfaz como:
	   - emitir mensaje a vop-panel
 	   - recibir acciones del vop-panel
	   
core.js: aplica transformaciones a los eventos del softswith y los emite a vop-hub
	       adicionalmente aplica transformaciones a las acciones y las ejecuta en el softswitch.

## pruebas duktape

* cada evaluacion sobre el mismo contexto mantiene las variables globales
  con esto se puede hacer actualizaciones en tiempo de ejecucion
- [Jovany Leandro G.C](https://github.com/your-github-user) - creator and maintainer
