#lang racket

(require "estado.rkt" "variables.rkt")
(provide buscar-morfema piezas-maximas aplicar-morfema resolver resolver-valor
         listo texto-rackituq)

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

(define (definir-morfema nombres clase proc)
  (for ([nombre nombres])
    (hash-set! diccionario nombre (morfema clase proc))))

(define (buscar-morfema nombre)
  (hash-ref diccionario nombre #f))

;; Cuántas piezas separadas por punto tiene el nombre más largo (`sub.lista` = 2)
(define (piezas-maximas)
  (for/fold ([m 1]) ([nombre (in-hash-keys diccionario)])
    (max m (length (string-split nombre "." #:trim? #f)))))

;; ----- RESOLUCIÓN DE VALORES -----

;; Un valor que ya fue resuelto y no se debe volver a leer como nombre
;; (por ejemplo un texto que salió de una lista)
(struct listo (valor))

;; Convertir un texto del programa en su valor
(define (resolver elemento)
  (cond
    [(regexp-match? #px"^\".*\"$" elemento)
     (substring elemento 1 (sub1 (string-length elemento)))]
    [(and (string-contains? elemento ",")
          (andmap string->number (string-split elemento ",")))
     (map string->number (string-split elemento ","))]
    [(string->number elemento) => values]
    [(hash-has-key? variables elemento) (hash-ref variables elemento)]
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
  (if (procedure? op)
      (apply op valor (map resolver-valor extras))
      (aplicar-morfema valor (string-trim op "." #:right? #f) extras)))

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
  (lambda (l [i 0]) (list-ref l (if (number? i) i 0))))
(definir-morfema '("long.itud" "longitud" "cuenta")  'valor
  (lambda (v) (if (string? v) (string-length v) (length v))))
(definir-morfema '("prim.ero" "primero")             'valor first)
(definir-morfema '("ult.imo" "ultimo")               'valor last)
(definir-morfema '("suma")                           'valor (lambda (l) (apply + l)))
(definir-morfema '("producto")                       'valor (lambda (l) (apply * l)))
(definir-morfema '("invierte")                       'valor reverse)
(definir-morfema '("ordena")                         'valor (lambda (l) (sort l <)))
(definir-morfema '("con")                            'valor (lambda (l x) (append l (list x))))

;; ----- TEXTO -----
(definir-morfema '("texto")                  'valor texto-rackituq)
(definir-morfema '("mayusculas")             'valor string-upcase)
(definir-morfema '("minusculas")             'valor string-downcase)
(definir-morfema '("recorta")                'valor string-trim)
;; "hola mundo".parte:" " -> ("hola" "mundo");  sin complemento parte por espacios
(definir-morfema '("parte")                  'valor
  (lambda (v [sep " "]) (string-split v sep)))
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

;; ----- TIPOS Y VARIABLES -----
;; `edad.es:numero?` usa el tipo declarado de la variable si lo tiene
(definir-morfema '("es") 'crudo
  (lambda (v comps raiz)
    (let ([tipo (string->symbol (first comps))])
      (if (and raiz (hash-has-key? tipos raiz))
          (verificar-tipo raiz tipo)
          (eq? (tipo-de v) tipo)))))
;; `...en:total` guarda el valor en una variable y lo deja seguir
(definir-morfema '("en" "guarda") 'crudo
  (lambda (v comps raiz)
    (let ([nombre (first comps)])
      (if (hash-has-key? variables nombre)
          (actualizar-variable nombre v)
          (definir-variable nombre v))
      v)))

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
