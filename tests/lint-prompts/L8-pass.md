# Lint fixture: L8 passes

Made-up text for scripts/lint-prompts.sh. The delay next to the rule name equals the live value.

Rule 61 - yield inside the NVS scan loop:
vTaskDelay(pdMS_TO_TICKS(5));

Line one.
Line two.
Line three.
Line four.
vTaskDelay(pdMS_TO_TICKS(250));
The delay above is seven lines away from the rule name, so L8 does not check it.
