#lang racket

(require "estado.rkt" "vocabulario.rkt")
(provide hablar evaluar-palabra ejecutar-palabra segmentar explicar tokenizar
         limite-repeticiones)

;; ----- SEGMENTADOR DE PALABRAS AGLUTINANTES -----
;;
;; Una palabra Rackituq se arma como en kalaallisut:
;;
;;     raíz . morfema . morfema:complemento ... [modo]
;;
;; La raíz es un valor (5, 1,2,3, "hola") o una variable. Cada morfema
;; transforma todo lo que va antes, de izquierda a derecha:
;;
;;     notas.solo:mayor:5.suma.muestra
;;
;; Si la raíz no tiene valor (`x.sum.ar 2 3`), la entrada sale de los
;; argumentos que van después de la palabra: el primero es la entrada y el
;; resto son complementos del primer morfema. `x.sum.ar 2 3` = `2.sum.ar:3`.
;;
;; El modo, pegado al final de la palabra, dice qué hacer con ella:
;;     ?         pregunta: responde sí/no
;;     -guni     condicional ("si..."): el resto de la oración va solo si es cierta
;;     -gaangat  habitual ("cada vez que..."): repite el resto mientras sea cierta

;; Los complementos pueden ser sub-palabras entre paréntesis: 5.por:(4.menos:1)
(instalar-evaluador! (lambda (texto) (ejecutar-palabra texto)))

;; Partir un texto por un carácter, sin mirar dentro de las comillas ni de los
;; paréntesis. El punto entre dígitos es decimal, no separador: 3.5 es un número
(define (partir texto separador)
  (let loop ([i 0] [inicio 0] [comillas? #f] [prof 0] [acc '()])
    (if (= i (string-length texto))
        (reverse (cons (substring texto inicio) acc))
        (let ([c (string-ref texto i)])
          (cond
            [(char=? c #\") (loop (add1 i) inicio (not comillas?) prof acc)]
            [comillas? (loop (add1 i) inicio comillas? prof acc)]
            [(char=? c #\() (loop (add1 i) inicio comillas? (add1 prof) acc)]
            [(char=? c #\)) (loop (add1 i) inicio comillas? (sub1 prof) acc)]
            [(and (zero? prof) (char=? c separador) (not (decimal? texto i separador)))
             (loop (add1 i) (add1 i) comillas? prof (cons (substring texto inicio i) acc))]
            [else (loop (add1 i) inicio comillas? prof acc)])))))

;; ¿Este punto es el de un número decimal?
(define (decimal? texto i separador)
  (and (char=? separador #\.)
       (> i 0)
       (< (add1 i) (string-length texto))
       (char-numeric? (string-ref texto (sub1 i)))
       (char-numeric? (string-ref texto (add1 i)))))

(define modos '(("?" . pregunta) ("-guni" . condicional) ("-gaangat" . habitual)))

;; Máximo de vueltas de -gaangat, para que un error no cuelgue el programa
(define limite-repeticiones 100000)

;; Marca de "esta raíz no tiene valor"
(define sin-valor (string->uninterned-symbol "sin-valor"))

;; Separar el modo del final de la palabra
(define (separar-modo palabra)
  (match (findf (lambda (m) (string-suffix? palabra (car m))) modos)
    [(cons marca modo)
     (values (substring palabra 0 (- (string-length palabra) (string-length marca))) modo)]
    [#f (values palabra 'afirmacion)]))

;; Unir piezas seguidas cuando juntas forman un morfema del diccionario,
;; prefiriendo siempre la coincidencia exacta más larga: sub + lista -> sub.lista
(define (unir-piezas piezas)
  (let loop ([ps piezas] [acc '()])
    (if (empty? ps)
        (reverse acc)
        (let ([k (for/first ([k (in-range (min (piezas-maximas) (length ps)) 1 -1)]
                             #:when (let ([grupo (take ps k)])
                                      ;; solo la última pieza del grupo puede llevar complementos
                                      (and (andmap (lambda (p) (empty? (cdr p))) (drop-right grupo 1))
                                           (buscar-morfema (string-join (map car grupo) ".")))))
                   k)])
          (if k
              (let ([grupo (take ps k)])
                (loop (drop ps k)
                      (cons (cons (string-join (map car grupo) ".") (cdr (last grupo))) acc)))
              (loop (rest ps) (cons (first ps) acc)))))))

;; Partir una palabra en su raíz y sus morfemas: cada morfema es (nombre . complementos)
;; ".sum.ar" (con punto inicial) no tiene raíz
(define (segmentar cuerpo)
  (let* ([piezas (filter non-empty-string? (partir cuerpo #\.))]
         [sin-raiz? (string-prefix? cuerpo ".")]
         [raiz (if (or sin-raiz? (empty? piezas)) "" (first piezas))]
         [resto (if (or sin-raiz? (empty? piezas)) piezas (rest piezas))])
    (values raiz
            (unir-piezas (for/list ([p resto])
                           (let ([elementos (partir p #\:)])
                             (cons (first elementos) (rest elementos))))))))

;; ¿La raíz es un literal o una variable?
(define (tiene-valor? raiz)
  (or (texto-literal? raiz)
      (lista-literal? raiz)
      (sub-palabra? raiz)
      (string->number raiz)
      (hash-has-key? variables raiz)))

;; Evaluar una palabra: devuelve su valor y su modo.
;; `posicionales` son los argumentos que van después de la palabra;
;; `entrada`, si se da, reemplaza a la raíz como valor inicial.
(define (evaluar-palabra palabra [posicionales '()] #:entrada [entrada sin-valor]
                         ;; `paso` recibe (nombre complementos valor) después de cada morfema
                         #:paso [paso void])
  (let*-values ([(cuerpo modo) (separar-modo palabra)]
                [(raiz morfemas) (segmentar cuerpo)]
                [(inicial args usa-raiz?)
                 (cond
                   [(not (eq? entrada sin-valor)) (values entrada posicionales #f)]
                   [(tiene-valor? raiz) (values (resolver raiz) posicionales #t)]
                   [(pair? posicionales)
                    (values (resolver-valor (first posicionales)) (rest posicionales) #f)]
                   [(string=? raiz "") (values (void) '() #f)]
                   [else (error (format "Error: No conozco la palabra ~a" raiz))])])
    (when (and (empty? morfemas) (pair? args))
      (error (format "Error: ~a no tiene sufijos que usen los argumentos ~a" palabra args)))
    (paso "raíz" (list raiz) inicial)
    (values (for/fold ([valor inicial])
                      ([m morfemas]
                       [i (in-naturals)])
              (let* ([complementos (if (zero? i) (append (cdr m) args) (cdr m))]
                     ;; El primer morfema recibe también los argumentos posicionales
                     [nuevo (aplicar-morfema valor (car m) complementos
                                             (and (zero? i) usa-raiz? raiz))])
                (paso (car m) complementos nuevo)
                nuevo))
            modo)))

;; Igual que evaluar-palabra, pero solo el valor
(define (ejecutar-palabra palabra [posicionales '()] #:entrada [entrada sin-valor])
  (let-values ([(valor modo) (evaluar-palabra palabra posicionales #:entrada entrada)])
    valor))

;; ----- ORACIONES -----

;; Palabras que arman la oración y nunca son argumentos
(define palabras-clave '("sino"))

;; Un token es argumento de la palabra anterior si es un número, un texto
;; entre comillas o un nombre suelto (sin punto)
(define (argumento? token)
  (and (not (member token palabras-clave))
       (or (string->number token)
           (texto-literal? token)
           (not (string-contains? token ".")))))

;; ¿La palabra lleva modo pegado al final?
(define (tiene-modo? palabra)
  (let-values ([(cuerpo modo) (separar-modo palabra)])
    (not (eq? modo 'afirmacion))))

;; Agrupar los tokens en palabras con sus argumentos: ((palabra arg ...) ...)
;; Una palabra con modo cierra su grupo: lo que sigue ya es otra palabra
(define (agrupar tokens)
  (reverse
   (for/fold ([grupos '()]) ([t tokens])
     (if (and (pair? grupos)
              (argumento? t)
              (not (tiene-modo? (last (first grupos)))))
         (cons (append (first grupos) (list t)) (rest grupos))
         (cons (list t) grupos)))))

(define (evaluar-grupo grupo)
  (evaluar-palabra (first grupo) (rest grupo)))

;; Partir los grupos en lo que va antes y después de `sino`
(define (partir-en-sino grupos)
  (let ([i (index-where grupos (lambda (g) (equal? (first g) "sino")))])
    (if i
        (values (take grupos i) (drop grupos (add1 i)))
        (values grupos '()))))

;; Evaluar una oración: palabras separadas por espacios
(define (evaluar-oracion grupos)
  (if (empty? grupos)
      (void)
      (let-values ([(valor modo) (evaluar-grupo (first grupos))]
                   [(resto) (rest grupos)])
        (case modo
          [(pregunta)
           (if (empty? resto) (texto-rackituq valor) (evaluar-oracion resto))]
          [(condicional)
           ;; `sino` parte la oración en las dos ramas
           (let-values ([(entonces si-no) (partir-en-sino resto)])
             (cond
               [valor (evaluar-oracion entonces)]
               [(empty? si-no) "Condición falsa"]
               [else (evaluar-oracion si-no)]))]
          [(habitual)
           (let loop ([cierto valor] [vueltas 0])
             (cond
               [(not cierto) "Bucle terminado"]
               [(>= vueltas limite-repeticiones)
                (error "Error: -gaangat dio demasiadas vueltas")]
               [else
                (evaluar-oracion resto)
                (let-values ([(v _) (evaluar-grupo (first grupos))])
                  (loop v (add1 vueltas)))]))]
          [else
           (if (empty? resto) valor (evaluar-oracion resto))]))))

;; Partir la línea en tokens respetando los textos entre comillas
(define (tokenizar linea)
  (regexp-match* #px"(?:\"[^\"]*\"|[^\\s\"])+" linea))

;; Punto de entrada: una línea de Rackituq
(define (hablar oracion)
  (evaluar-oracion (agrupar (tokenizar oracion))))

;; ----- EXPLICAR -----

;; Mostrar una palabra paso a paso y devolver su valor y su modo
(define (explicar-grupo grupo)
  (displayln (string-join grupo " "))
  (let-values ([(valor modo)
                (evaluar-palabra
                 (first grupo) (rest grupo)
                 #:paso (lambda (nombre complementos valor)
                          (printf "   ~a  →  ~a\n"
                                  (if (string=? nombre "raíz")
                                      (format "raíz ~a" (first complementos))
                                      (string-join (cons nombre (map texto-rackituq complementos)) ":"))
                                  (texto-rackituq valor))))])
    (unless (eq? modo 'afirmacion)
      (printf "   modo ~a  →  ~a\n" modo (texto-rackituq valor)))
    (values valor modo)))

;; Mostrar una oración paso a paso, diciendo qué rama toma cada condicional
(define (explicar-grupos grupos)
  (unless (empty? grupos)
    (let-values ([(valor modo) (explicar-grupo (first grupos))])
      (case modo
        [(condicional)
         (let-values ([(entonces si-no) (partir-en-sino (rest grupos))])
           (cond
             [valor
              (displayln "   condición cierta  →  sigue la oración")
              (explicar-grupos entonces)]
             [(empty? si-no)
              (displayln "   condición falsa  →  la oración no sigue")]
             [else
              (displayln "   condición falsa  →  toma la rama sino")
              (explicar-grupos si-no)]))]
        [(habitual)
         ;; El bucle no se repite aquí: explicar muestra una sola vuelta
         (displayln "   modo habitual  →  se repetiría; explicar muestra una vuelta")
         (explicar-grupos (rest grupos))]
        [else (explicar-grupos (rest grupos))]))))

;; Mostrar una línea paso a paso: qué hace cada morfema con el valor
(define (explicar linea)
  (explicar-grupos (agrupar (tokenizar linea))))
