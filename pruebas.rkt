#lang racket

;; Pruebas de Rackituq. Correr con:  raco test pruebas.rkt

(require rackunit
         "nucleo/estado.rkt" "nucleo/ejecutor.rkt" "nucleo/palabra.rkt" "nucleo/repl.rkt")

;; Capturar lo que se imprime
(define (salida-de thunk)
  (with-output-to-string thunk))

;; ----- SEGMENTADOR -----

(define (morfemas-de palabra)
  (let-values ([(raiz morfemas) (segmentar palabra)])
    (cons raiz (map car morfemas))))

(test-case "el punto siempre separa y gana la coincidencia exacta más larga"
  (check-equal? (morfemas-de "lista1.sub.lista") '("lista1" "sub.lista"))
  (check-equal? (morfemas-de "x.lista") '("x" "lista"))
  (check-equal? (morfemas-de "x.sum.ar.raiz") '("x" "sum.ar" "raiz"))
  (check-equal? (morfemas-de ".mem.limpiar") '("" "mem.limpiar"))
  (check-equal? (morfemas-de "3.5.dobla") '("3.5" "dobla")))

;; ----- ESTILO CLÁSICO (los 7 bugs) -----

(test-case "bug 1: .sub.lista ya no queda tapado por .lista"
  (ejecutar-comando "definir.variable" "p-lista" '(10 20 30 40 50))
  (check-equal? (ejecutar-comando "p-lista.sub.lista" 1 3) '(20 30))
  (check-equal? (ejecutar-comando "x.lista" 1 2) '(1 2)))

(test-case "bug 2: mem.limpiar vacía la caché"
  (ejecutar-comando "x.mem.cache" 'clave (lambda () 42))
  (check-equal? (hash-ref memoria-cache 'clave) 42)
  (ejecutar-comando "mem.limpiar" #f)
  (check-equal? (hash-count memoria-cache) 0))

(test-case "bug 3: las funciones recursivas conocen los operadores de Racket"
  (ejecutar-comando "definir.funcion.recursiva" "p-fact" 'n '(if (= n 0) 1 (* n (p-fact (- n 1)))))
  (check-equal? (ejecutar-comando "p-fact" 5) 120)
  (ejecutar-comando "definir.funcion.recursiva" "p-pot" '(b e) '(if (= e 0) 1 (* b (p-pot b (- e 1)))))
  (check-equal? (ejecutar-comando "p-pot" '(2 10)) 1024))

(test-case "bug 4: exportar e importar módulos"
  (define archivo (make-temporary-file "rackituq-~a.rkq"))
  (ejecutar-comando "definir.variable" "p-notas" '(7 8 10))
  (ejecutar-comando "exportar.modulo" '("p-notas") archivo)
  (hash-remove! variables "p-notas")
  (ejecutar-comando "importar.modulo" archivo)
  (check-equal? (hash-ref variables "p-notas") '(7 8 10))
  (delete-file archivo))

(test-case "bug 5: map/filter/reduce usan la operación que se les da"
  (ejecutar-comando "definir.variable" "p-nums" '(1 2 3 4 5 6))
  (check-equal? (ejecutar-comando "x.map" "p-nums" add1) '(2 3 4 5 6 7))
  (check-equal? (ejecutar-comando "x.filter" "p-nums" even?) '(2 4 6))
  (check-equal? (ejecutar-comando "x.reduce" "p-nums" ".mult.iplicar") 720)
  (check-equal? (ejecutar-comando "p-nums.map" "dobla") '(2 4 6 8 10 12)))

(test-case "bug 6: una variable con tipo rechaza valores de otro tipo"
  (ejecutar-comando "definir.variable.tipo" "p-edad" 20 'numero)
  (check-equal? (ejecutar-comando "actualizar.variable" "p-edad" 21)
                "Variable p-edad actualizada con valor 21")
  (check-exn #rx"es de tipo numero" (lambda () (ejecutar-comando "actualizar.variable" "p-edad" "veinte"))))

(test-case "bug 7: el REPL llega a si, mientras y definir.variable.tipo"
  (check-equal? (ejecutar-linea "definir.variable.tipo p-e 16 numero")
                "Variable p-e definida como número con valor 16")
  (check-equal? (ejecutar-linea "si p-e 17 < x.sum.ar 100") 116)
  (ejecutar-linea "definir.variable p-i 0")
  ;; el cuerpo guarda el nuevo valor con .en:
  (check-equal? (ejecutar-linea "mientras p-i 5 < x.sum.ar.en:p-i 1") "Bucle terminado")
  (check-equal? (hash-ref variables "p-i") 5))

(test-case "un mientras que no avanza se corta con un error que lo explica"
  (ejecutar-linea "definir.variable p-quieto 0")
  (check-exn #rx"demasiadas vueltas" (lambda () (ejecutar-linea "mientras p-quieto 3 < x.sum.ar 1"))))

(test-case "las operaciones binarias reciben sus dos argumentos"
  (check-equal? (ejecutar-comando "x.sum.ar" 2 3) 5)
  (check-equal? (ejecutar-comando "x.div.idir" 10 4) 5/2)
  (check-equal? (ejecutar-linea "x.sum.ar 2 3") 5))

(test-case "mostrar.salida funciona con uno o dos argumentos"
  (check-equal? (salida-de (lambda () (ejecutar-comando "mostrar.salida" "Hola Mundo"))) "Hola Mundo\n")
  (check-equal? (salida-de (lambda () (ejecutar-comando "mostrar.salida" "Hola ~a" "Mundo"))) "Hola Mundo\n")
  (check-equal? (salida-de (lambda () (ejecutar-linea "mostrar.salida \"Hola Mundo\""))) "Hola Mundo\n")
  (ejecutar-linea "definir.variable p-nombre \"Mundo\"")
  (check-equal? (salida-de (lambda () (ejecutar-linea "mostrar.salida \"Hola ~a\" p-nombre"))) "Hola Mundo\n"))

;; ----- ESTILO AGLUTINANTE -----

(test-case "los morfemas se encadenan"
  (check-equal? (hablar "5.mas:3.por:2") 16)
  (check-equal? (hablar "x.sum.ar.raiz 7 9") 4)
  (check-equal? (hablar "1,2,3,4,5,6.solo:par.cada:por:10.suma") 120)
  (check-equal? (hablar "1,2,3.junta:menos") -4)
  (check-equal? (hablar "10,20,30,40,50.sublista:1:3") '(20 30)))

(test-case "los nombres clásicos y sus alias son el mismo morfema"
  (check-equal? (hablar "2.sum.ar:3") (hablar "2.sumar:3"))
  (check-equal? (hablar "2.sumar:3") (hablar "2.mas:3")))

(test-case "orden superior anidado"
  (check-equal? (hablar "1,2,3.lista.cada:cada:por:2") '((2 4 6))))

(test-case "hola mundo"
  (check-equal? (salida-de (lambda () (hablar "\"Hola Mundo\".mostrar"))) "Hola Mundo\n"))

(test-case "modos: pregunta, condicional y habitual"
  (check-equal? (hablar "7.impar?") "sí")
  (hablar "20.en:p-adulto")
  (check-equal? (salida-de (lambda () (hablar "p-adulto.mayor:17-guni \"adulto\".muestra"))) "adulto\n")
  (check-equal? (hablar "p-adulto.menor:17-guni \"menor\".muestra") "Condición falsa")
  (hablar "0.en:p-j")
  (check-equal? (hablar "p-j.menor:5-gaangat p-j.mas:1.en:p-j") "Bucle terminado")
  (check-equal? (hash-ref variables "p-j") 5))

(test-case "sino: la otra rama del condicional"
  (hablar "16.en:p-menor")
  (check-equal? (salida-de (lambda () (hablar "p-menor.mayor:17-guni \"adulto\".muestra sino \"menor\".muestra")))
                "menor\n")
  (hablar "20.en:p-menor")
  (check-equal? (salida-de (lambda () (hablar "p-menor.mayor:17-guni \"adulto\".muestra sino \"menor\".muestra")))
                "adulto\n")
  ;; sin sino, una condición falsa sigue avisando
  (hablar "16.en:p-menor")
  (check-equal? (hablar "p-menor.mayor:17-guni \"adulto\".muestra") "Condición falsa"))

(test-case "listas de texto y mezcladas"
  (check-equal? (hablar "\"a\",\"b\",\"c\".cada:mayusculas.une:\"-\"") "A-B-C")
  (check-equal? (hablar "\"a\",\"b\".cuenta") 2)
  (check-equal? (hablar "1,\"dos\",3.cuenta") 3)
  (check-equal? (hablar "\"hola mundo\",\"chao\".primero") "hola mundo"))

(test-case "explicar muestra la palabra paso a paso"
  (check-equal? (salida-de (lambda () (explicar "1,2,3.cada:por:10.suma")))
                (string-append "1,2,3.cada:por:10.suma\n"
                               "   raíz 1,2,3  →  (1 2 3)\n"
                               "   cada:por:10  →  (10 20 30)\n"
                               "   suma  →  60\n")))

(test-case "tipos desde las palabras"
  (ejecutar-comando "definir.variable.tipo" "p-t" 3 'numero)
  (check-equal? (hablar "p-t.es:numero?") "sí")
  (check-exn #rx"es de tipo numero" (lambda () (hablar "\"x\".en:p-t"))))

(test-case "sufijos definidos en Rackituq"
  (ejecutar-comando "definir.sufijo" "p-cuad-mas-uno" "a-la:2.mas:1")
  (check-equal? (hablar "3.p-cuad-mas-uno") 10)
  (check-equal? (hablar "1,2,3.cada:p-cuad-mas-uno") '(2 5 10))
  (check-equal? (ejecutar-linea "definir.sufijo p-triple por:3") "Sufijo p-triple definido como por:3")
  (check-equal? (hablar "4.p-triple.p-triple") 36))

(test-case "sufijos con complementos propios"
  (ejecutar-comando "definir.sufijo" "p-aumentar-en" "mas:$1")
  (check-equal? (hablar "5.p-aumentar-en:3") 8)
  (check-equal? (hablar "1,2,3.cada:p-aumentar-en:10") '(11 12 13))
  (ejecutar-comando "definir.sufijo" "p-escala" "por:$1.mas:$2")
  (check-equal? (hablar "10.p-escala:3:1") 31)
  (check-exn #rx"necesita 1 complemento" (lambda () (hablar "5.p-aumentar-en"))))

(test-case "morfemas de texto"
  (check-equal? (hablar "\"hola \".concatenar:\"mundo\".mayusculas") "HOLA MUNDO")
  (check-equal? (hablar "\"hola mundo\".parte.cada:mayusculas.une:\"-\"") "HOLA-MUNDO")
  (check-equal? (hablar "\"hola mundo\".reemplaza:\"mundo\":\"tierra\"") "hola tierra")
  (check-equal? (hablar "\"  hola  \".recorta.cuenta") 4)
  (check-equal? (hablar "5.texto.concatenar:\" gatos\"") "5 gatos")
  (check-equal? (hablar "1,2,3.une:\" + \"") "1 + 2 + 3")
  (check-equal? (hablar "\"hola mundo\".contiene:\"mundo\"?") "sí")
  ;; los morfemas de lista siguen funcionando con listas
  (check-equal? (hablar "1,2,3.concatenar:4,5") '(1 2 3 4 5))
  (check-equal? (hablar "1,2,3.cuenta") 3))

(test-case "sub-palabras entre paréntesis"
  (check-equal? (hablar "5.por:(4.menos:1)") 15)
  (check-equal? (hablar "(2.mas:3).por:2") 10)
  (check-equal? (hablar "10.menos:(2.por:(1.mas:2))") 4)
  (check-equal? (hablar "1,2,3.cada:por:(1.mas:1)") '(2 4 6))
  ;; el punto decimal sigue siendo parte del número
  (check-equal? (hablar "3.5.dobla") 7.0))

(test-case "recursión escrita en Rackituq con $0"
  (ejecutar-linea "definir.sufijo p-fact $0.menor:2-guni 1 sino $0.por:($0.menos:1.p-fact)")
  (check-equal? (hablar "5.p-fact") 120)
  (check-equal? (hablar "1,2,3,4,5.cada:p-fact") '(1 2 6 24 120))
  (ejecutar-linea "definir.sufijo p-fib $0.menor:2-guni $0 sino ($0.menos:1.p-fib).mas:($0.menos:2.p-fib)")
  (check-equal? (hablar "10.p-fib") 55))

(test-case "promedios legibles"
  (check-equal? (hablar "7,8,10,5,9.promedio") 39/5)
  (check-equal? (hablar "7,8,10,5,9.promedio.decimal") 7.8)
  (check-equal? (hablar "7,8,10,5,9.promedio.redondea") 8))

(test-case "correr un programa guardado"
  (define archivo (make-temporary-file "rackituq-~a.rkq"))
  (display-to-file (string-join '(";; un programa de prueba"
                                  "definir.variable p-notas2 7,8,10"
                                  ""
                                  "p-notas2.promedio.decimal.en:p-prom")
                                "\n")
                   archivo #:exists 'replace)
  (check-equal? (correr-archivo archivo) (format "Programa ~a terminado" archivo))
  (check-equal? (hash-ref variables "p-prom") 8.333333333333334)
  ;; un error dice en qué línea fue
  (display-to-file "banana.suma" archivo #:exists 'replace)
  (check-exn #rx"en la línea 1" (lambda () (correr-archivo archivo)))
  (delete-file archivo))

(test-case "explicar dice qué rama toma el condicional"
  (check-equal? (salida-de (lambda () (explicar "16.mayor:17-guni \"grande\".muestra sino \"chico\".muestra")))
                (string-append "16.mayor:17-guni\n"
                               "   raíz 16  →  16\n"
                               "   mayor:17  →  no\n"
                               "   modo condicional  →  no\n"
                               "   condición falsa  →  toma la rama sino\n"
                               "\"chico\".muestra\n"
                               "   raíz \"chico\"  →  chico\n"
                               "chico\n"
                               "   muestra  →  chico\n")))

(test-case "cada llamada a un sufijo tiene sus variables locales"
  ;; guarda ANTES de la llamada recursiva: sin ámbitos locales se pisaría
  (ejecutar-linea "definir.sufijo p-fact2 $0.menor:2-guni 1 sino $0.en:n ($0.menos:1.p-fact2).por:n")
  (check-equal? (hablar "5.p-fact2") 120)
  (check-equal? (hablar "1,2,3,4,5.cada:p-fact2") '(1 2 6 24 120))
  ;; lo local no se filtra hacia afuera
  (check-exn #rx"No conozco la palabra n" (lambda () (hablar "n"))))

(test-case "en: guarda aquí y global: guarda afuera"
  (ejecutar-linea "definir.variable p-total 0")
  (ejecutar-linea "definir.sufijo p-acumular $0.mas:p-total.global:p-total")
  (check-equal? (hablar "5.p-acumular") 5)
  (check-equal? (hablar "7.p-acumular") 12)
  (check-equal? (hablar "p-total") 12)
  ;; el mismo sufijo con en: no toca la global
  (ejecutar-linea "definir.sufijo p-no-toca $0.en:p-total p-total")
  (check-equal? (hablar "99.p-no-toca") 99)
  (check-equal? (hablar "p-total") 12))

(test-case "un sufijo que no arranca con morfema se lee como oración"
  (ejecutar-linea "definir.variable p-cuenta 0")
  (ejecutar-linea "definir.sufijo p-contar p-cuenta.mas:1.global:p-cuenta")
  (hablar "1,2,3.cada:p-contar")
  (check-equal? (hablar "p-cuenta") 3))

(test-case "condiciones combinadas con y, o, no"
  (ejecutar-linea "definir.variable p-anios 30")
  (check-equal? (hablar "p-anios.mayor:17.y:(p-anios.menor:65)?") "sí")
  (check-equal? (hablar "p-anios.mayor:17.y:(p-anios.menor:25)?") "no")
  (check-equal? (hablar "p-anios.mayor:99.o:(p-anios.par)?") "sí")
  (check-equal? (hablar "p-anios.mayor:99.no?") "sí")
  ;; sí y no también se pueden escribir
  (check-equal? (hablar "sí.y:(no)?") "no")
  (check-equal? (hablar "no.no?") "sí"))

(test-case "una cadena entre paréntesis sirve de operación"
  (check-equal? (hablar "1,2,3.cada:(mas:1.por:2)") '(4 6 8))
  ;; `esto` es el valor que llega; `otro` el que lo acompaña en junta:
  (check-equal? (hablar "1,2,3,4,5,6.solo:(mayor:2.y:(esto.menor:6))") '(3 4 5))
  (check-equal? (hablar "1,2,3.junta:(mas:otro)") 6))

(test-case "errores claros"
  (check-exn #rx"No conozco la palabra banana" (lambda () (hablar "banana.suma")))
  (check-exn #rx"No conozco el sufijo volar" (lambda () (hablar "5.volar")))
  (check-exn #rx"demasiadas vueltas" (lambda () (hablar "1.en:p-k p-k.mayor:0-gaangat p-k.mas:1.en:p-k"))))
