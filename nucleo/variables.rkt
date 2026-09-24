#lang racket

(require "errores.rkt" "estado.rkt")
(provide (all-defined-out))

;; ----- ÁMBITOS -----
;;
;; Cada llamada a un sufijo abre un ámbito propio. Un nombre se busca de
;; adentro hacia afuera: primero los ámbitos locales, al final el global.
;; Así una recursión que guarda un valor intermedio no se pisa a sí misma.

(define (ambito-actual)
  (if (empty? (unbox ambitos)) variables (first (unbox ambitos))))

(define (abrir-ambito!)
  (set-box! ambitos (cons (make-hash) (unbox ambitos))))

(define (cerrar-ambito!)
  (set-box! ambitos (rest (unbox ambitos))))

;; Correr algo en un ámbito nuevo, cerrándolo aunque haya un error
(define (con-ambito-nuevo pensar)
  (dynamic-wind abrir-ambito! pensar cerrar-ambito!))

;; La tabla donde vive el nombre, o #f si no está en ninguna
(define (tabla-de nombre)
  (or (for/first ([a (unbox ambitos)] #:when (hash-has-key? a nombre)) a)
      (and (hash-has-key? variables nombre) variables)))

(define (variable-existe? nombre)
  (and (tabla-de nombre) #t))

;; ----- PALABRAS RESERVADAS -----
;;
;; El lenguaje usa estos nombres para sí mismo, así que no pueden nombrar una
;; variable: si se pudiera, la variable quedaría inalcanzable. Están en
;; ESPECIFICACION.md.
;;   sí, no      los valores booleanos
;;   sino        separa las dos ramas de un condicional
;;   esto, otro  el valor que llega a una cadena y el que la acompaña
;;   $0, $1, ... el valor y los complementos de un sufijo
(define palabras-reservadas '("sí" "no" "sino" "esto" "otro"))

(define (reservada? nombre)
  (and (string? nombre)
       (or (and (member nombre palabras-reservadas) #t)
           (regexp-match? #px"^\\$[0-9]+$" nombre))))

;; El lenguaje mismo sí puede usarlas (así ata `esto` o `$0`); un programa no
(define (comprobar-nombre nombre)
  (when (reservada? nombre)
    (error-reservada nombre)))

;; ----- SISTEMA DE INMUTABILIDAD -----

;; Función para definir una variable inmutable
(define (definir-variable nombre valor)
  (comprobar-nombre nombre)
  (when (hash-has-key? (ambito-actual) nombre)
    (error-variable-existe nombre))
  (hash-set! (ambito-actual) nombre valor)
  (format "Variable ~a definida con valor ~a" nombre valor))

;; Definir siempre en el ámbito actual, tape o no una variable de afuera
(define (definir-local nombre valor)
  (hash-set! (ambito-actual) nombre valor)
  (format "Variable local ~a definida con valor ~a" nombre valor))

;; Función para obtener una variable con verificación de existencia
(define (obtener-variable nombre)
  (let ([tabla (tabla-de nombre)])
    (if tabla
        (hash-ref tabla nombre)
        (error-variable-no-encontrada nombre))))

;; Actualizar una variable (solo para variables mutables)
(define (actualizar-variable nombre valor)
  (comprobar-nombre nombre)
  (let ([tabla (tabla-de nombre)])
    (cond
      [(not tabla)
       (error-variable-no-encontrada nombre)]
      ;; Una variable global con tipo declarado solo acepta valores de ese tipo
      [(and (eq? tabla variables)
            (hash-has-key? tipos nombre)
            (not (verificar-tipo nombre (tipo-de valor))))
       (error-tipo-variable nombre (hash-ref tipos nombre) valor)]
      [else
       (hash-set! tabla nombre valor)
       (format "Variable ~a actualizada con valor ~a" nombre valor)])))

;; Guardar en el ámbito actual: dentro de un sufijo es local a esa llamada,
;; y arriba es global. Así una recursión no pisa lo que guardó la de afuera
(define (guardar-variable nombre valor)
  (comprobar-nombre nombre)
  (if (and (eq? (ambito-actual) variables) (hash-has-key? variables nombre))
      ;; arriba, sobre una variable que ya existe, valen los tipos declarados
      (actualizar-variable nombre valor)
      (begin
        (hash-set! (ambito-actual) nombre valor)
        (format "Variable ~a guardada con valor ~a" nombre valor))))

;; Guardar en el ámbito global aunque estemos dentro de un sufijo
(define (guardar-global nombre valor)
  (comprobar-nombre nombre)
  (if (hash-has-key? variables nombre)
      (let ([guardados (unbox ambitos)])
        ;; el chequeo de tipos mira el ámbito global
        (set-box! ambitos '())
        (begin0 (actualizar-variable nombre valor)
                (set-box! ambitos guardados)))
      (begin
        (hash-set! variables nombre valor)
        (format "Variable global ~a definida con valor ~a" nombre valor))))

;; ----- SISTEMA DE TIPOS -----

;; Función para definir una variable con tipo
(define (definir-variable-con-tipo nombre valor tipo)
  (comprobar-nombre nombre)
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
    [else (error-tipo-valor valor tipo)]))

;; Tipo Rackituq de un valor
(define (tipo-de valor)
  (cond
    [(number? valor) 'numero]
    [(string? valor) 'texto]
    [(list? valor) 'lista]
    [(hash? valor) 'diccionario]
    [(boolean? valor) 'booleano]
    [(procedure? valor) 'funcion]
    [else 'desconocido]))

;; Verificar tipo de una variable
(define (verificar-tipo nombre tipo-esperado)
  (if (hash-has-key? tipos nombre)
      (eq? (hash-ref tipos nombre) tipo-esperado)
      #f))
