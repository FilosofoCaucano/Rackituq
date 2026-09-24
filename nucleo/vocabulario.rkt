#lang racket

(require "estado.rkt" "variables.rkt")
(provide buscar-morfema piezas-maximas aplicar-morfema resolver resolver-valor
         listo texto-rackituq texto-literal? lista-literal? sub-palabra?
         instalar-evaluador! instalar-encadenador! texto-de-valor)

;; ----- DICCIONARIO DE MORFEMAS -----
;;
;; Cada morfema es una pieza con significado propio. Se registra una sola vez
;; con todos sus nombres: el clásico con punto (`sum.ar`) y sus alias sin
;; punto (`sumar`, `mas`). Agregar un morfema nuevo es agregar una línea.
;;
;; Hay dos clases de morfema:
;;   'valor  recibe el valor que se viene formando y sus complementos ya
;;           resueltos: `mas:3` -> (+ valor 3)
;;   'crudo  recibe los complementos sin resolver, porque son nombres de
;;           otros morfemas o de variables: `cada:por:2`, `en:total`

(struct morfema (clase proc))

(define diccionario (make-hash))

;; Cuántas piezas separadas por punto tiene el nombre más largo (`sub.lista` = 2).
;; Se guarda al registrar, porque el segmentador lo consulta en cada pieza
(define max-piezas 1)

(define (definir-morfema nombres clase proc)
  (for ([nombre nombres])
    (hash-set! diccionario nombre (morfema clase proc))
    (set! max-piezas (max max-piezas (length (string-split nombre "." #:trim? #f))))))

(define (buscar-morfema nombre)
  (hash-ref diccionario nombre #f))

(define (piezas-maximas) max-piezas)

;; ----- RESOLUCIÓN DE VALORES -----

;; Un valor que ya fue resuelto y no se debe volver a leer como nombre
;; (por ejemplo un texto que salió de una lista)
(struct listo (valor))

;; ----- FORMA DE LOS ELEMENTOS -----

;; Un texto entre comillas: "hola mundo"
(define patron-texto "\"[^\"]*\"")
;; Un número: 5, -3, 3.5
(define patron-numero "-?[0-9]+(?:\\.[0-9]+)?")
;; Una lista escrita con comas: 1,2,3 o "a","b" o 1,"dos"
(define patron-lista
  (format "(?:~a|~a)(?:,(?:~a|~a))+" patron-texto patron-numero patron-texto patron-numero))
;; Las expresiones regulares se compilan una sola vez: se usan en cada morfema
(define regex-lista (pregexp (format "^(?:~a)$" patron-lista)))
(define regex-pedazo-lista (pregexp (format "~a|[^,]+" patron-texto)))
(define regex-texto (pregexp (format "^(?:~a)$" patron-texto)))

;; Un solo texto entre comillas; "a","b" son dos, no uno
(define (texto-literal? elemento)
  (and (string-prefix? elemento "\"")
       (regexp-match? regex-texto elemento)))

(define (lista-literal? elemento)
  (and (string-contains? elemento ",")
       (regexp-match? regex-lista elemento)))

;; Una sub-palabra entre paréntesis: por:(3.mas:1)
(define (sub-palabra? elemento)
  (and (string-prefix? elemento "(") (string-suffix? elemento ")")))

;; Lo que va entre los paréntesis
(define (interior elemento)
  (substring elemento 1 (sub1 (string-length elemento))))

;; palabra.rkt instala aquí cómo se evalúa una sub-palabra suelta, y cómo se
;; aplica una cadena de morfemas a un valor: 1,2,3.cada:(mas:1.por:2)
(define evaluador-sub-palabra (box #f))
(define encadenador (box #f))
(define (instalar-evaluador! f) (set-box! evaluador-sub-palabra f))
(define (instalar-encadenador! f) (set-box! encadenador f))

;; Convertir un texto del programa en su valor
(define (resolver elemento)
  (cond
    ;; Primero lo barato: número, texto, sub-palabra
    [(string->number elemento) => values]
    [(texto-literal? elemento)
     (substring elemento 1 (sub1 (string-length elemento)))]
    ;; Una sub-palabra se evalúa antes: 5.por:(4.menos:1) = 15
    [(sub-palabra? elemento) ((unbox evaluador-sub-palabra) (interior elemento))]
    ;; Los sí/no se pueden escribir, no solo salir de un predicado
    [(string=? elemento "sí") #t]
    [(string=? elemento "no") #f]
    [(lista-literal? elemento)
     ;; Las comas separan, pero no dentro de las comillas
     (map resolver (regexp-match* regex-pedazo-lista elemento))]
    [(variable-existe? elemento) (obtener-variable elemento)]
    [else (error (format "Error: No conozco la palabra ~a" elemento))]))

;; Los textos se leen como nombres o literales; los demás valores pasan tal cual
(define (resolver-valor x)
  (cond
    [(listo? x) (listo-valor x)]
    [(string? x) (resolver x)]
    [else x]))

;; ----- APLICACIÓN -----

;; Aplicar un morfema (o una función del usuario) al valor
(define (aplicar-morfema valor nombre complementos [raiz #f])
  (cond
    [(buscar-morfema nombre)
     => (lambda (m)
          (cond
            [(eq? (morfema-clase m) 'crudo)
             ((morfema-proc m) valor complementos raiz)]
            [(not (procedure-arity-includes? (morfema-proc m) (add1 (length complementos))))
             (error (format "Error: ~a no acepta ~a complemento(s); recibió ~a"
                            nombre (length complementos) (map resolver-valor complementos)))]
            [else
             (apply (morfema-proc m) valor (map resolver-valor complementos))]))]
    ;; Las funciones que define el usuario también se pegan como morfemas
    [(hash-ref funciones nombre #f)
     => (lambda (f) (apply f valor (map resolver-valor complementos)))]
    [else (error (format "Error: No conozco el sufijo ~a" nombre))]))

;; La operación que reciben cada/solo/junta: un procedimiento de Racket,
;; o el nombre de un morfema o función (".sum.ar", "por", "cuadrado")
(define (aplicar-operacion op valor extras)
  (cond
    [(procedure? op) (apply op valor (map resolver-valor extras))]
    ;; Una cadena entre paréntesis se aplica al valor: cada:(mas:1.por:2)
    [(sub-palabra? op) ((unbox encadenador) (interior op) valor extras)]
    [else (aplicar-morfema valor (string-trim op "." #:right? #f) extras)]))

;; Cómo se escribe un valor para volver a meterlo en una palabra
(define (texto-de-valor v)
  (cond
    [(string? v) (format "~s" v)]
    [(eq? v #t) "sí"]
    [(eq? v #f) "no"]
    [(list? v) (string-join (map texto-de-valor v) ",")]
    [else (format "~a" v)]))

;; Cómo se lee un valor en Rackituq: los booleanos son sí/no
(define (texto-rackituq v)
  (cond
    [(eq? v #t) "sí"]
    [(eq? v #f) "no"]
    [else (format "~a" v)]))

;; Namespace para las lambdas que se arman en tiempo de ejecución
(define ns-lambdas (make-base-namespace))

;; ----- ARITMÉTICA -----
(definir-morfema '("sum.ar" "sumar" "mas")             'valor (lambda (v . ns) (apply + v ns)))
(definir-morfema '("rest.ar" "restar" "menos")         'valor (lambda (v . ns) (apply - v ns)))
(definir-morfema '("mult.iplicar" "multiplicar" "por") 'valor (lambda (v . ns) (apply * v ns)))
(definir-morfema '("div.idir" "dividir" "entre")       'valor (lambda (v . ns) (apply / v ns)))
(definir-morfema '("pot.enciar" "potenciar" "a-la")    'valor expt)
(definir-morfema '("mod.ul" "modulo" "mod")            'valor modulo)
(definir-morfema '("dobla")                            'valor (lambda (v) (* v 2)))
(definir-morfema '("neg")                              'valor -)
;; 39/5 es exacto pero se lee mal: .decimal da 7.8, .redondea da 8
(definir-morfema '("decimal")                          'valor exact->inexact)
(definir-morfema '("redondea")                         'valor (lambda (v) (inexact->exact (round v))))
(definir-morfema '("promedio")                         'valor (lambda (l) (/ (apply + l) (length l))))

;; ----- FUNCIONES MATEMÁTICAS -----
(definir-morfema '("raiz")                          'valor sqrt)
(definir-morfema '("sin.us" "seno")                 'valor sin)
(definir-morfema '("cos.inus" "coseno")             'valor cos)
(definir-morfema '("tan.gente" "tangente")          'valor tan)
(definir-morfema '("log.aritmo" "logaritmo")        'valor log)
(definir-morfema '("exp.onencial" "exponencial")    'valor exp)
(definir-morfema '("abs.oluto" "absoluto" "abs")    'valor abs)
(definir-morfema '("rand.aleatorio" "aleatorio")    'valor random)
;; Con varios números da el menor/mayor; con una lista, el de la lista
(definir-morfema '("min.imo" "minimo") 'valor
  (lambda (v . ns) (if (and (list? v) (empty? ns)) (apply min v) (apply min v ns))))
(definir-morfema '("max.imo" "maximo") 'valor
  (lambda (v . ns) (if (and (list? v) (empty? ns)) (apply max v) (apply max v ns))))

;; ----- LISTAS -----
(definir-morfema '("lista")                          'valor (lambda (v . ns) (cons v ns)))
(definir-morfema '("sub.lista" "sublista" "desde")   'valor (lambda (l i j) (take (drop l i) (- j i))))
;; Sirve para listas y para textos: "hola ".concatenar:"mundo"
(definir-morfema '("conc.atenar" "concatenar" "pega") 'valor
  (lambda (v . resto)
    (if (string? v) (apply string-append v (map texto-rackituq resto)) (apply append v resto))))
(definir-morfema '("ind.ice" "indice")               'valor
  (lambda (l [i 0])
    (let ([n (if (number? i) i 0)])
      (if (string? l) (substring l n (add1 n)) (list-ref l n)))))
(definir-morfema '("long.itud" "longitud" "cuenta")  'valor
  (lambda (v) (if (string? v) (string-length v) (length v))))
;; Sirven para listas y para textos
(definir-morfema '("prim.ero" "primero")             'valor
  (lambda (v) (if (string? v) (substring v 0 1) (first v))))
(definir-morfema '("ult.imo" "ultimo")               'valor
  (lambda (v) (if (string? v) (substring v (sub1 (string-length v))) (last v))))
(definir-morfema '("invierte")                       'valor
  (lambda (v) (if (string? v) (list->string (reverse (string->list v))) (reverse v))))
(definir-morfema '("suma")                           'valor (lambda (l) (apply + l)))
(definir-morfema '("producto")                       'valor (lambda (l) (apply * l)))
(definir-morfema '("ordena")                         'valor (lambda (l) (sort l <)))
(definir-morfema '("con")                            'valor (lambda (l x) (append l (list x))))

;; ----- TEXTO -----
(definir-morfema '("texto")                  'valor texto-rackituq)
;; "hola".letra:0 -> "h";  "hola mundo".trozo:0:4 -> "hola"
(definir-morfema '("letra")                  'valor
  (lambda (v i) (substring v i (add1 i))))
(definir-morfema '("trozo")                  'valor
  (lambda (v desde [hasta #f]) (substring v desde (or hasta (string-length v)))))
(definir-morfema '("mayusculas")             'valor string-upcase)
(definir-morfema '("minusculas")             'valor string-downcase)
(definir-morfema '("recorta")                'valor string-trim)
;; "hola mundo".parte:" " -> ("hola" "mundo");  sin complemento parte por
;; espacios, y con "" parte en letras
(definir-morfema '("parte")                  'valor
  (lambda (v [sep " "])
    (if (string=? sep "")
        (map string (string->list v))
        (string-split v sep))))
;; ("hola" "mundo").une:" " -> "hola mundo"
(definir-morfema '("une")                    'valor
  (lambda (l [sep " "]) (string-join (map texto-rackituq l) sep)))
(definir-morfema '("contiene")               'valor
  (lambda (v x) (if (string? v) (string-contains? v x) (and (member x v) #t))))
(definir-morfema '("reemplaza")              'valor
  (lambda (v viejo nuevo) (string-replace v viejo nuevo)))

;; ----- ORDEN SUPERIOR: su complemento es otra operación -----
;; `cada:por:10`, `solo:mayor:2`, `junta:mas`; se pueden anidar: `cada:solo:par`
(definir-morfema '("map" "cada") 'crudo
  (lambda (l comps raiz)
    (map (lambda (x) (aplicar-operacion (first comps) x (rest comps))) l)))
(definir-morfema '("filter" "filtra" "solo") 'crudo
  (lambda (l comps raiz)
    (filter (lambda (x) (aplicar-operacion (first comps) x (rest comps))) l)))
;; Reduce de izquierda a derecha: 1,2,3.junta:menos = (1 - 2) - 3
(definir-morfema '("reduce" "junta") 'crudo
  (lambda (l comps raiz)
    (for/fold ([acc (first l)]) ([x (rest l)])
      (aplicar-operacion (first comps) acc (list (listo x))))))

;; ----- ERRORES -----
;; `intenta:(cadena)` devuelve no si la cadena falla, y con una segunda cadena
;; usa esa como respaldo; dentro del respaldo, `otro` es el mensaje del error
(definir-morfema '("intenta") 'crudo
  (lambda (v comps raiz)
    (with-handlers ([exn:fail?
                     (lambda (e)
                       (if (>= (length comps) 2)
                           (aplicar-operacion (second comps) v (list (listo (exn-message e))))
                           #f))])
      (aplicar-operacion (first comps) v '()))))

;; `falla:"mensaje"` corta la oración con ese error
(definir-morfema '("falla") 'valor
  (lambda (v mensaje) (error (format "Error: ~a" mensaje))))

;; ----- PREDICADOS: sirven con el modo pregunta (?), con -guni y con `solo:` -----
(definir-morfema '("par")      'valor even?)
(definir-morfema '("impar")    'valor odd?)
(definir-morfema '("positivo") 'valor positive?)
(definir-morfema '("negativo") 'valor negative?)
(definir-morfema '("cero")     'valor zero?)
(definir-morfema '("vacia")    'valor empty?)
(definir-morfema '("mayor")    'valor (lambda (v n) (> v n)))
(definir-morfema '("menor")    'valor (lambda (v n) (< v n)))
(definir-morfema '("igual")    'valor (lambda (v n) (equal? v n)))
(definir-morfema '("distinto") 'valor (lambda (v n) (not (equal? v n))))
;; Combinar condiciones. El complemento suele ser una sub-palabra:
;; edad.mayor:17.y:(edad.menor:65). Son de corto circuito: el segundo lado
;; se evalúa solo si hace falta
(definir-morfema '("y") 'crudo
  (lambda (v comps raiz)
    (and (not (eq? v #f))
         (not (eq? (resolver-valor (first comps)) #f)))))
(definir-morfema '("o") 'crudo
  (lambda (v comps raiz)
    (or (not (eq? v #f))
        (not (eq? (resolver-valor (first comps)) #f)))))
(definir-morfema '("no" "niega") 'valor (lambda (v) (eq? v #f)))

;; ----- TIPOS Y VARIABLES -----
;; `edad.es:numero?` usa el tipo declarado de la variable si lo tiene
(definir-morfema '("es") 'crudo
  (lambda (v comps raiz)
    (let ([tipo (string->symbol (first comps))])
      (if (and raiz (hash-has-key? tipos raiz))
          (verificar-tipo raiz tipo)
          (eq? (tipo-de v) tipo)))))
;; `...en:total` guarda el valor en una variable y lo deja seguir.
;; Si el nombre ya existe lo actualiza donde viva; si no, lo crea aquí mismo
(definir-morfema '("en" "guarda") 'crudo
  (lambda (v comps raiz)
    (guardar-variable (first comps) v)
    v))

;; `...global:total` guarda afuera, aunque estemos dentro de un sufijo
(definir-morfema '("global") 'crudo
  (lambda (v comps raiz)
    (guardar-global (first comps) v)
    v))

;; ----- EVALUACIÓN DIFERIDA Y LAMBDAS -----
(definir-morfema '("lazy" "diferir")            'valor (lambda (x) (delay x)))
(definir-morfema '("force" "forzar")            'valor force)
(definir-morfema '("lambda.simple")             'valor
  (lambda (params cuerpo) (eval `(lambda ,params ,cuerpo) ns-lambdas)))
(definir-morfema '("lambda.multi")              'valor
  (lambda (params cuerpo) (eval `(lambda ,params ,@cuerpo) ns-lambdas)))
(definir-morfema '("lambda.aplicar" "aplicar")  'valor (lambda (func args) (apply func args)))

;; ----- MEMORIA -----
(definir-morfema '("mem.cache") 'valor
  (lambda (key func)
    (if (hash-has-key? memoria-cache key)
        (hash-ref memoria-cache key)
        (let ([result (func)])
          (hash-set! memoria-cache key result)
          result))))
(definir-morfema '("mem.limpiar") 'valor (lambda (v . _) (hash-clear! memoria-cache)))

;; ----- SALIDA -----
(definir-morfema '("muestra" "mostrar") 'valor
  (lambda (v) (displayln (texto-rackituq v)) v))
