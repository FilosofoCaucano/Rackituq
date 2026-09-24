#lang racket

(provide (all-defined-out))

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

;; Pila de ámbitos locales: cada llamada a un sufijo o función abre uno.
;; Las variables de arriba viven en `variables`, que es el ámbito global
(define ambitos (box '()))

;; Cuerpo en texto de los sufijos definidos en Rackituq, para poder exportarlos
(define sufijos (make-hash))
