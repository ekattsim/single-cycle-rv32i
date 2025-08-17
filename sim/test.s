.global start
.text

start:
    /* load registers */
    lw x10, 400(x0)
    lw x11, 404(x0)

    /* compute and store */
    and x12, x10, x11
    sw x12, 408(x0)

    or x13, x10, x11
    sw x13, 412(x0)

    add x14, x10, x11
    sw x14, 416(x0)

    sub x15, x10, x11
    sw x15, 420(x0)

    /* loop if x10=x11 */
    beq x10, x11, -20

    /* zero out stores if x10!=x11 */
    sw x0, 408(x0)
    sw x0, 412(x0)
    sw x0, 416(x0)
    sw x0, 420(x0)

loop:
    beq x0, x0, 0
