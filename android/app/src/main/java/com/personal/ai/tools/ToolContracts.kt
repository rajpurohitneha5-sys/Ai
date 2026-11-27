package com.personal.ai.tools

/** Modular tool contracts for search, file analysis, image generation, coding and data analysis. */
data class ToolInput(val argumentsJson: String)
data class ToolOutput(val content: String, val metadataJson: String = "{}", val isError: Boolean = false)
interface AiTool { val name: String; val description: String; suspend fun execute(input: ToolInput): ToolOutput }
class ToolRegistry(private val tools: List<AiTool>) { fun list(): List<AiTool> = tools; fun find(name: String): AiTool? = tools.firstOrNull { it.name == name } }
