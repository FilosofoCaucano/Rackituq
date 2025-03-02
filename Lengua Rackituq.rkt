#lang racket

;; ----- ESTRUCTURAS DE DATOS PRINCIPALES -----

;; Tabla de almacenamiento de variables con gestión de tipos
(define variables (make-hash))
(define tipos (make-hash))

;; Tabla de almacenamiento de funciones
(define funciones (make-hash))

;; Tabla para módulos importados
(define modulos (make-hash))

;; Caché para optimización de memoria
(define memoria-cache (make-hash))

;; ----- ANALIZADOR DE SUFIJOS -----

;; Definir un parser que reconozca sufijos y los traduzca a operaciones
(define (interpretar codigo)
  (cond
    ;; Operaciones aritméticas básicas
    [(string-suffix? codigo ".sum.ar") +]
    [(string-suffix? codigo ".rest.ar") -]
    [(string-suffix? codigo ".mult.iplicar") *]
    [(string-suffix? codigo ".div.idir") /]
    [(string-suffix? codigo ".pot.enciar") expt]
    [(string-suffix? codigo ".mod.ul") modulo]
    
    ;; Funciones matemáticas
    [(string-suffix? codigo ".raiz") sqrt]
    [(string-suffix? codigo ".sin.us") sin]
    [(string-suffix? codigo ".cos.inus") cos]
    [(string-suffix? codigo ".tan.gente") tan]
    [(string-suffix? codigo ".log.aritmo") log]
    [(string-suffix? codigo ".exp.onencial") exp]
    [(string-suffix? codigo ".abs.oluto") abs]
    [(string-suffix? codigo ".min.imo") min]
    [(string-suffix? codigo ".max.imo") max]
    [(string-suffix? codigo ".rand.aleatorio") random]
    
    ;; Operaciones de listas
    [(string-suffix? codigo ".lista") list]
    [(string-suffix? codigo ".map") map]
    [(string-suffix? codigo ".filter") filter]
    [(string-suffix? codigo ".reduce") foldl]
    [(string-suffix? codigo ".conc.atenar") append]
    [(string-suffix? codigo ".ind.ice") list-ref]
    [(string-suffix? codigo ".sub.lista") (lambda (lst inicio fin) 
                                            (take (drop lst inicio) (- fin inicio)))]
    [(string-suffix? codigo ".long.itud") length]
    [(string-suffix? codigo ".prim.ero") first]
    [(string-suffix? codigo ".ult.imo") last]
    
    ;; Evaluación diferida
    [(string-suffix? codigo ".lazy") (lambda (x) (delay x))]
    [(string-suffix? codigo ".force") (lambda (x) (force x))]
    
    ;; Expresiones lambda avanzadas
    [(string-suffix? codigo ".lambda.simple") (lambda (params cuerpo) 
                                               (eval `(lambda ,params ,cuerpo)))]
    [(string-suffix? codigo ".lambda.multi") (lambda (params cuerpo) 
                                              (eval `(lambda ,params ,@cuerpo)))]
    [(string-suffix? codigo ".lambda.aplicar") (lambda (func args) (apply func args))]
    
    ;; Manejo avanzado de memoria
    [(string-suffix? codigo ".mem.cache") (lambda (key func) 
                                           (if (hash-has-key? memoria-cache key)
                                               (hash-ref memoria-cache key)
                                               (let ([result (func)])
                                                 (hash-set! memoria-cache key result)
                                                 result)))]
    [(string-suffix? codigo ".mem.limpiar") (lambda () (set! memoria-cache (make-hash)))]
    
    [else 'error]))

;; ----- SISTEMA DE INMUTABILIDAD -----

;; Función para definir una variable inmutable
(define (definir-variable nombre valor)
  (when (hash-has-key? variables nombre)
    (error (format "Error: La variable ~a ya está definida" nombre)))
  (hash-set! variables nombre valor)
  (format "Variable ~a definida con valor ~a" nombre valor))

;; Función para obtener una variable con verificación de existencia
(define (obtener-variable nombre)
  (if (hash-has-key? variables nombre)
      (hash-ref variables nombre)
      (error (format "Error: Variable ~a no encontrada" nombre))))

;; Actualizar una variable (solo para variables mutables)
(define (actualizar-variable nombre valor)
  (if (hash-has-key? variables nombre)
      (begin
        (hash-set! variables nombre valor)
        (format "Variable ~a actualizada con valor ~a" nombre valor))
      (error (format "Error: Variable ~a no encontrada" nombre))))

;; ----- SISTEMA DE TIPOS -----

;; Función para definir una variable con tipo
(define (definir-variable-con-tipo nombre valor tipo)
  (cond
    [(and (eq? tipo 'numero) (number? valor))
     (hash-set! variables nombre valor)
     (hash-set! tipos nombre 'numero)
     (format "Variable ~a definida como número con valor ~a" nombre valor)]
    [(and (eq? tipo 'texto) (string? valor))
     (hash-set! variables nombre valor)
     (hash-set! tipos nombre 'texto)
     (format "Variable ~a definida como texto con valor ~a" nombre valor)]
    [(and (eq? tipo 'lista) (list? valor))
     (hash-set! variables nombre valor)
     (hash-set! tipos nombre 'lista)
     (format "Variable ~a definida como lista con valor ~a" nombre valor)]
    [(and (eq? tipo 'booleano) (boolean? valor))
     (hash-set! variables nombre valor)
     (hash-set! tipos nombre 'booleano)
     (format "Variable ~a definida como booleano con valor ~a" nombre valor)]
    [(and (eq? tipo 'funcion) (procedure? valor))
     (hash-set! variables nombre valor)
     (hash-set! tipos nombre 'funcion)
     (format "Variable ~a definida como función" nombre)]
    [else (format "Error: El valor ~a no coincide con el tipo ~a" valor tipo)]))

;; Verificar tipo de una variable
(define (verificar-tipo nombre tipo-esperado)
  (if (hash-has-key? tipos nombre)
      (eq? (hash-ref tipos nombre) tipo-esperado)
      #f))

;; ----- DEFINICIÓN DE FUNCIONES -----

;; Función para definir una función personalizada
(define (definir-funcion nombre operacion parametro)
  (hash-set! funciones nombre (lambda (x) (ejecutar-comando operacion x parametro)))
  (format "Función ~a definida." nombre))

;; Función para definir una función recursiva
(define (definir-funcion-recursiva nombre parametros cuerpo)
  (letrec ([func (lambda (args)
                   (let ([params (if (list? parametros) parametros (list parametros))]
                         [args-list (if (list? args) args (list args))])
                     (let* ([env (for/hash ([p params]
                                            [a args-list])
                                   (values p a))]
                            [extended-env (hash-set env nombre func)])
                       (eval-with-env cuerpo extended-env))))])
    (hash-set! funciones nombre func)
    (format "Función recursiva ~a definida." nombre)))

;; Evaluador con entorno
(define (eval-with-env expr env)
  (cond
    [(symbol? expr) (hash-ref env expr)]
    [(pair? expr)
     (let ([op (eval-with-env (car expr) env)]
           [args (map (lambda (arg) (eval-with-env arg env)) (cdr expr))])
       (apply op args))]
    [else expr]))

;; ----- SOPORTE PARA MÓDULOS -----

;; Importar un módulo
(define (importar-modulo ruta)
  (if (file-exists? ruta)
      (let ([mod-env (make-hash)])
        (with-input-from-file ruta
          (lambda ()
            (let loop ([expr (read)])
              (unless (eof-object? expr)
                (eval expr)
                (loop (read))))))
        (hash-set! modulos (path->string ruta) mod-env)
        (format "Módulo ~a importado correctamente" ruta))
      (format "Error: No se pudo encontrar el módulo ~a" ruta)))

;; Exportar definiciones a un módulo
(define (exportar-a-modulo nombres ruta)
  (with-output-to-file ruta #:exists 'replace
    (lambda ()
      (for ([nombre nombres])
        (if (hash-has-key? variables nombre)
            (printf "(define ~a ~a)\n" nombre (hash-ref variables nombre))
            (if (hash-has-key? funciones nombre)
                (printf "(define ~a ~a)\n" nombre (hash-ref funciones nombre))
                (format "Error: ~a no está definido" nombre))))))
  (format "Definiciones exportadas a ~a" ruta))

;; ----- EVALUACIÓN DE CONDICIONES -----

;; Función para evaluar condiciones
(define (evaluar-condicion x operador y)
  (cond
    [(string=? operador ">") (> x y)]
    [(string=? operador "<") (< x y)]
    [(string=? operador "==") (= x y)]
    [(string=? operador "!=") (not (= x y))]
    [(string=? operador ">=") (>= x y)]
    [(string=? operador "<=") (<= x y)]
    [(string=? operador "and") (and x y)]
    [(string=? operador "or") (or x y)]
    [(string=? operador "not") (not x)]
    [else #f]))

;; ----- ENTRADA/SALIDA -----

;; Función para leer entrada del usuario
(define (leer-input mensaje)
  (display mensaje)
  (flush-output)
  (read))

;; Función para mostrar salida formateada
(define (mostrar-salida formato . args)
  (apply printf (cons formato args))
  (newline))

;; ----- EJECUTOR PRINCIPAL -----

;; Función para ejecutar comandos
(define (ejecutar-comando comando x [y #f] [operador #f] [operacion #f] [param #f])
  (cond
    ;; Definición de variables y funciones
    [(string-prefix? comando "definir.")
     (cond
       [(string=? comando "definir.variable")
        (definir-variable x y)]
       [(string=? comando "definir.variable.tipo")
        (definir-variable-con-tipo x y operador)]
       [(string=? comando "definir.funcion")
        (definir-funcion x y operador)]
       [(string=? comando "definir.funcion.recursiva")
        (definir-funcion-recursiva x y operador)]
       [else (definir-variable (substring comando 8) x)])]
    
    ;; Actualización de variables
    [(string=? comando "actualizar.variable")
     (actualizar-variable x y)]
    
    ;; Manejo de funciones
    [(hash-has-key? funciones comando)
     (let ([func (hash-ref funciones comando)])
       (if (procedure? func)
           (func x)
           "Error: La función no es válida"))]
    
    ;; Estructuras de control
    [(string=? comando "si")
     (if (evaluar-condicion (obtener-variable x) operador y)
         (ejecutar-comando operacion x param)
         "Condición falsa")]
    
    [(string=? comando "mientras")
     (let loop ([valor-x (obtener-variable x)])
       (if (evaluar-condicion valor-x operador y)
           (begin 
             (ejecutar-comando operacion valor-x param)
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
    
    [(string=? comando "mostrar.salida")
     (mostrar-salida x y)]
    
    ;; Manejo de memoria
    [(string=? comando "mem.limpiar")
     ((interpretar "mem.limpiar"))]
    
    ;; Ejecución de operaciones generales
    [else
     (let* ([operacion (interpretar comando)]
            [valor-x (if (string? x) (obtener-variable x) x)]
            [valor-y (if (and y (string? y)) (obtener-variable y) y)])
       (cond
         ;; Error de comando
         [(eq? operacion 'error) 
          "Error: Comando inválido"]
         
         ;; Funciones unarias
         [(or (eq? operacion sqrt) (eq? operacion sin) (eq? operacion cos)
              (eq? operacion tan) (eq? operacion log) (eq? operacion exp) 
              (eq? operacion abs) (eq? operacion first) (eq? operacion last)
              (eq? operacion length))
          (operacion valor-x)]
         
         ;; Random solo usa un argumento
         [(eq? operacion random) 
          (random valor-x)]
         
         ;; Operaciones de listas
         [(eq? operacion list) 
          (apply list (cons valor-x (if y (list valor-y) '())))]
         
         [(eq? operacion map) 
          (map (lambda (x) (if (number? x) (* x 2) x)) valor-x)]
         
         [(eq? operacion filter) 
          (filter (lambda (x) (if (number? x) (> x 2) #f)) valor-x)]
         
         [(eq? operacion foldl) 
          (foldl + 0 valor-x)]
         
         [(eq? operacion append)
          (append valor-x valor-y)]
         
         [(eq? operacion list-ref)
          (list-ref valor-x (if (number? valor-y) valor-y 0))]
         
         ;; Expresiones lambda
         [(or (string-suffix? comando ".lambda.simple") 
              (string-suffix? comando ".lambda.multi"))
          (operacion valor-x valor-y)]
         
         [(string-suffix? comando ".lambda.aplicar")
          (operacion valor-x valor-y)]
         
         ;; Funciones para lazy evaluation
         [(procedure? operacion) 
          (operacion valor-x)]
         
         ;; Operaciones binarias por defecto
         [else (operacion valor-x valor-y)]))])) 

;; ----- REPL (Read-Eval-Print Loop) -----

;; Función REPL básico para pruebas
(define (repl)
  (display "Racketiitut> ")
  (flush-output)
  (let ([entrada (read-line)])
    (unless (equal? entrada "salir")
      (let* ([tokens (string-split entrada " ")]
             [comando (car tokens)]
             [args (cdr tokens)])
        (cond
          [(empty? args)
           (display (ejecutar-comando comando #f))]
          [(= (length args) 1)
           (display (ejecutar-comando comando (car args)))]
          [(= (length args) 2)
           (display (ejecutar-comando comando (car args) (cadr args)))]
          [else
           (display (ejecutar-comando comando (car args) (cadr args) (caddr args)))]))
      (newline)
      (repl))))

;; Ejemplo de uso: descomentar para probar el REPL
;; (repl)


(displayln (format "Sublista de lista1 (1-3): ~a" 
                  (ejecutar-comando "lista1.sub.lista" 1 3)))