#lang racket

(require "estado.rkt")
(require "variables.rkt")
(require "modulos.rkt")
(require "condiciones.rkt")
(require "io.rkt")
(require "vocabulario.rkt")
(require "palabra.rkt")
(provide (all-defined-out))

;; ----- EJECUTOR PRINCIPAL -----

;; Quitar los #f que sobran al final (argumentos opcionales que no se dieron)
(define (sin-vacios-al-final lst)
  (reverse (dropf (reverse lst) not)))

;; Función para ejecutar comandos
(define (ejecutar-comando comando x [y #f] [operador #f] [operacion #f] [param #f])
  (cond
    ;; Definición de variables y funciones
    [(string-prefix? comando "definir.")
     (cond
       [(string=? comando "definir.variable")
        (definir-variable x y)]
       [(string=? comando "definir.variable.tipo")
        (definir-variable-con-tipo x y (if (string? operador) (string->symbol operador) operador))]
       [(string=? comando "definir.funcion")
        (definir-funcion x y operador)]
       [(string=? comando "definir.funcion.recursiva")
        (definir-funcion-recursiva x y operador)]
       [(string=? comando "definir.sufijo")
        (definir-sufijo x y)]
       [else (definir-variable (substring comando 8) x)])]
    
    ;; Actualización de variables
    [(string=? comando "actualizar.variable")
     (actualizar-variable x y)]
    
    ;; Manejo de funciones
    [(hash-has-key? funciones comando)
     (let ([func (hash-ref funciones comando)])
       (if (procedure? func)
           (func (resolver-valor x))
           "Error: La función no es válida"))]
    
    ;; Estructuras de control: la operación se aplica al valor de la variable
    [(string=? comando "si")
     (if (evaluar-condicion (obtener-variable x) operador y)
         (ejecutar-palabra operacion (sin-vacios-al-final (list param))
                           #:entrada (obtener-variable x))
         "Condición falsa")]
    
    [(string=? comando "mientras")
     (let loop ([valor-x (obtener-variable x)])
       (if (evaluar-condicion valor-x operador y)
           (begin
             ;; El resultado del cuerpo se guarda en la variable; si no, el bucle nunca avanza
             (actualizar-variable x (ejecutar-palabra operacion (sin-vacios-al-final (list param))
                                                      #:entrada valor-x))
             (loop (obtener-variable x)))
           "Bucle terminado"))]
    
    ;; Manejo de módulos
    [(string=? comando "importar.modulo")
     (importar-modulo x)]
    
    [(string=? comando "exportar.modulo")
     (exportar-a-modulo x y)]
    
    ;; IO y otros comandos
    [(string=? comando "leer.input") 
     (leer-input x)]
    
    ;; Con un solo argumento se muestra tal cual; con dos, el primero es el formato
    [(string=? comando "mostrar.salida")
     (if y
         ;; El valor puede ser el nombre de una variable: mostrar.salida "Hola ~a" nombre
         (mostrar-salida x (if (and (string? y) (hash-has-key? variables y)) (hash-ref variables y) y))
         (mostrar-salida "~a" x))]
    
    ;; Manejo de memoria
    [(string=? comando "mem.limpiar")
     (hash-clear! memoria-cache)]
    
    ;; Todo lo demás es una palabra aglutinante con argumentos posicionales:
    ;; (ejecutar-comando "x.sum.ar" 2 3) = 2.sum.ar:3
    [else
     (ejecutar-palabra comando (sin-vacios-al-final (list x y operador operacion param)))]))

;; ----- DEFINICIÓN DE SUFIJOS -----

;; Guardar una cadena de morfemas como un sufijo nuevo:
;; (definir-sufijo "cuadrado-mas-uno" "a-la:2.mas:1")  ->  3.cuadrado-mas-uno = 10
(define (definir-sufijo nombre cadena)
  (let ([palabra (if (string-prefix? cadena ".") cadena (string-append "." cadena))])
    (hash-set! funciones nombre
               (lambda (v . _) (ejecutar-palabra palabra #:entrada v)))
    (format "Sufijo ~a definido como ~a" nombre cadena)))

;; ----- DEFINICIÓN DE FUNCIONES -----

;; Función para definir una función personalizada
(define (definir-funcion nombre operacion parametro)
  (hash-set! funciones nombre
             (lambda (x . _)
               (ejecutar-palabra operacion (sin-vacios-al-final (list parametro)) #:entrada x)))
  (format "Función ~a definida." nombre))

;; Función para definir una función recursiva
(define (definir-funcion-recursiva nombre parametros cuerpo)
  (letrec ([func (lambda args
                   (let* ([params (if (list? parametros) parametros (list parametros))]
                          ;; Con varios parámetros se acepta también una sola lista de argumentos
                          [args-list (if (and (> (length params) 1) (= (length args) 1) (list? (car args)))
                                         (car args)
                                         args)])
                     (let* ([env (for/hash ([p params]
                                            [a args-list])
                                   (values p a))]
                            ;; El cuerpo se llama a sí mismo por símbolo, no por texto
                            [extended-env (hash-set env (if (string? nombre) (string->symbol nombre) nombre) func)])
                       (eval-with-env cuerpo extended-env))))])
    (hash-set! funciones nombre func)
    (format "Función recursiva ~a definida." nombre)))

;; Operadores base de Racket (+, -, =, ...) disponibles en el cuerpo de las funciones
(define ns-base (make-base-namespace))

;; Evaluador con entorno
(define (eval-with-env expr env)
  (cond
    [(symbol? expr)
     (hash-ref env expr
               (lambda ()
                 (namespace-variable-value expr #t
                                           (lambda () (error (format "Error: No conozco ~a" expr)))
                                           ns-base)))]
    ;; `if` es forma especial: solo se evalúa la rama elegida (si no, la recursión nunca termina)
    [(and (pair? expr) (eq? (car expr) 'if))
     (if (eval-with-env (cadr expr) env)
         (eval-with-env (caddr expr) env)
         (eval-with-env (cadddr expr) env))]
    [(and (pair? expr) (eq? (car expr) 'quote))
     (cadr expr)]
    [(pair? expr)
     (let ([op (eval-with-env (car expr) env)]
           [args (map (lambda (arg) (eval-with-env arg env)) (cdr expr))])
       (apply op args))]
    [else expr]))
