#lang racket

(require "estado.rkt")
(provide (all-defined-out))

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
  (cond
    [(not (hash-has-key? variables nombre))
     (error (format "Error: Variable ~a no encontrada" nombre))]
    ;; Una variable con tipo declarado solo acepta valores de ese tipo
    [(and (hash-has-key? tipos nombre)
          (not (verificar-tipo nombre (tipo-de valor))))
     (error (format "Error: La variable ~a es de tipo ~a, no acepta ~a"
                    nombre (hash-ref tipos nombre) valor))]
    [else
     (hash-set! variables nombre valor)
     (format "Variable ~a actualizada con valor ~a" nombre valor)]))

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

;; Tipo Rackituq de un valor
(define (tipo-de valor)
  (cond
    [(number? valor) 'numero]
    [(string? valor) 'texto]
    [(list? valor) 'lista]
    [(boolean? valor) 'booleano]
    [(procedure? valor) 'funcion]
    [else 'desconocido]))

;; Verificar tipo de una variable
(define (verificar-tipo nombre tipo-esperado)
  (if (hash-has-key? tipos nombre)
      (eq? (hash-ref tipos nombre) tipo-esperado)
      #f))
