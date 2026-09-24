#lang racket

(provide (all-defined-out))

;; ----- CATÁLOGO DE ERRORES -----
;;
;; Todos los errores del lenguaje se arman acá, para que tengan siempre la
;; misma forma: "Error: " seguido de qué pasó, en minúscula y en español.
;; El catálogo con su significado está en ESPECIFICACION.md.

(define (fallar formato . args)
  (error (string-append "Error: " (apply format formato args))))

;; --- Nombres y variables ---
(define (error-variable-existe nombre)
  (fallar "la variable ~a ya está definida" nombre))

(define (error-variable-no-encontrada nombre)
  (fallar "no conozco la variable ~a" nombre))

(define (error-palabra-desconocida palabra)
  (fallar "no conozco la palabra ~a" palabra))

(define (error-sufijo-desconocido nombre)
  (fallar "no conozco el sufijo ~a" nombre))

(define (error-reservada nombre)
  (fallar "la palabra reservada ~s no puede ser el nombre de una variable" nombre))

;; --- Tipos ---
(define (error-tipo-variable nombre tipo valor)
  (fallar "la variable ~a es de tipo ~a, no acepta ~a" nombre tipo valor))

(define (error-tipo-valor valor tipo)
  (fallar "el valor ~a no es de tipo ~a" valor tipo))

(define (error-no-numero valor)
  (fallar "el valor ~s no es un número" valor))

;; --- Complementos y argumentos ---
(define (error-complementos-morfema nombre cuantos recibidos)
  (fallar "~a no acepta ~a complemento(s); recibió ~a" nombre cuantos recibidos))

(define (error-complementos-sufijo nombre necesita recibidos)
  (fallar "el sufijo ~a necesita ~a complemento(s); recibió ~a" nombre necesita recibidos))

(define (error-argumentos-sobran palabra args)
  (fallar "~a no tiene sufijos que usen los argumentos ~a" palabra args))

;; Un morfema que no pudo con el valor que le llegó. Se guarda el mensaje
;; original de Racket entre paréntesis, porque suele decir qué esperaba
(define (error-morfema-fallo nombre detalle)
  (fallar "el morfema ~a no pudo con ese valor (~a)" nombre detalle))

;; --- Bucles ---
(define (error-vueltas-gaangat)
  (fallar "-gaangat dio demasiadas vueltas"))

(define (error-vueltas-mientras nombre)
  (fallar "mientras dio demasiadas vueltas; ¿el cuerpo guarda el nuevo valor en ~a?" nombre))

;; --- Diccionarios ---
(define (error-diccionario-pares)
  (fallar "un diccionario necesita pares de clave y valor"))

(define (error-diccionario-clave clave)
  (fallar "el diccionario no tiene ~s" clave))

;; --- Módulos y programas ---
(define (error-modulo-no-encontrado ruta)
  (fallar "no se pudo encontrar el módulo ~a" ruta))

(define (error-en-linea mensaje numero linea)
  (error (format "~a\n   en la línea ~a: ~a" mensaje numero linea)))

;; --- Otros ---
(define (error-funcion-invalida nombre)
  (fallar "~a no es una función válida" nombre))

;; Nombre que el cuerpo de una función de Racket no conoce
(define (error-nombre-racket nombre)
  (fallar "no conozco ~a" nombre))

;; El error que levanta el propio programa con `falla:"..."`
(define (error-del-programa mensaje)
  (fallar "~a" mensaje))
