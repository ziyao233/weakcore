		.global		_start
		.global		print_int

		.section	.text.start
_start:
		li		sp,		0xfff0

		call		main

		li		t0,		0x80000008
		sw		zero,		0(t0)

print_int:
		li		t0,		0x80000000
		sw		a0,		0(t0)
		ret
