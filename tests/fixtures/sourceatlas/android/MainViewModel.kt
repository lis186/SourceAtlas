package com.example.app

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import javax.inject.Inject

interface DataRepository {
    fun getData(): String
}

class MainViewModel @Inject constructor(
    private val repository: DataRepository
) : ViewModel() {
    
    private val _data = MutableLiveData<String>()
    val data: LiveData<String> = _data
    
    fun loadData() {
        val result = repository.getData()
        _data.value = processData(result)
    }
    
    private fun processData(input: String): String {
        return input.uppercase()
    }
    
    object Constants {
        const val DEFAULT_VALUE = "default"
    }
}