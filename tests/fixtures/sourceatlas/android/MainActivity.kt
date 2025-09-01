package com.example.app

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.ViewModelProvider
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : AppCompatActivity() {
    
    private lateinit var viewModel: MainViewModel
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        viewModel = ViewModelProvider(this).get(MainViewModel::class.java)
        setupObservers()
    }
    
    private fun setupObservers() {
        viewModel.data.observe(this) { data ->
            updateUI(data)
        }
    }
    
    internal fun updateUI(data: String) {
        // Update UI with data
        println("Updating UI with: $data")
    }
    
    companion object {
        const val EXTRA_ID = "extra_id"
    }
}