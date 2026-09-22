#lang racket

(require "estado.rkt" "vocabulario.rkt")
(provide hablar evaluar-palabra ejecutar-palabra segmentar)

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

;; Un elemento es un texto entre comillas, una lista de números, un número o un nombre
(define patron-elemento
  (pregexp (string-append "\"[^\"]*\""
                          "|-?[0-9]+(?:\\.[0-9]+)?(?:,-?[0-9]+(?:\\.[0-9]+)?)+"
                          "|-?[0-9]+(?:\\.[0-9]+)?"
                          "|[^.:\"\\s]+")))

;; Una pieza es un elemento con sus complementos: `desde:1:3`
(define patron-pieza
  (pregexp (format "(?:~a)(?::(?:~a))*"
                   (object-name patron-elemento) (object-name patron-elemento))))

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
  (let* ([piezas (regexp-match* patron-pieza cuerpo)]
         [sin-raiz? (string-prefix? cuerpo ".")]
         [raiz (if (or sin-raiz? (empty? piezas)) "" (first piezas))]
         [resto (if (or sin-raiz? (empty? piezas)) piezas (rest piezas))])
    (values raiz
            (unir-piezas (for/list ([p resto])
                           (let ([elementos (regexp-match* patron-elemento p)])
                             (cons (first elementos) (rest elementos))))))))

;; ¿La raíz es un literal o una variable?
(define (tiene-valor? raiz)
  (or (regexp-match? #px"^\".*\"$" raiz)
      (string->number raiz)
      (and (string-contains? raiz ",") (andmap string->number (string-split raiz ",")))
      (hash-has-key? variables raiz)))

;; Evaluar una palabra: devuelve su valor y su modo.
;; `posicionales` son los argumentos que van después de la palabra;
;; `entrada`, si se da, reemplaza a la raíz como valor inicial.
(define (evaluar-palabra palabra [posicionales '()] #:entrada [entrada sin-valor])
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
    (values (for/fold ([valor inicial])
                      ([m morfemas]
                       [i (in-naturals)])
              (if (zero? i)
                  ;; El primer morfema recibe también los argumentos posicionales
                  (aplicar-morfema valor (car m) (append (cdr m) args) (and usa-raiz? raiz))
                  (aplicar-morfema valor (car m) (cdr m))))
            modo)))

;; Igual que evaluar-palabra, pero solo el valor
(define (ejecutar-palabra palabra [posicionales '()] #:entrada [entrada sin-valor])
  (let-values ([(valor modo) (evaluar-palabra palabra posicionales #:entrada entrada)])
    valor))

;; ----- ORACIONES -----

;; Un token es argumento de la palabra anterior si es un número, un texto
;; entre comillas o un nombre suelto (sin punto)
(define (argumento? token)
  (or (string->number token)
      (regexp-match? #px"^\"[^\"]*\"$" token)
      (not (string-contains? token "."))))

;; Agrupar los tokens en palabras con sus argumentos: ((palabra arg ...) ...)
(define (agrupar tokens)
  (reverse
   (for/fold ([grupos '()]) ([t tokens])
     (if (and (pair? grupos) (argumento? t))
         (cons (append (first grupos) (list t)) (rest grupos))
         (cons (list t) grupos)))))

(define (evaluar-grupo grupo)
  (evaluar-palabra (first grupo) (rest grupo)))

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
           (if valor (evaluar-oracion resto) "Condición falsa")]
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

;; Punto de entrada: una línea de Rackituq
(define (hablar oracion)
  (evaluar-oracion (agrupar (regexp-match* #px"(?:\"[^\"]*\"|[^\\s\"])+" oracion))))
